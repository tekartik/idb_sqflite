import 'package:idb_shim/idb_client.dart';
import 'package:idb_sqflite/src/sqflite_database.dart';
import 'package:idb_sqflite/src/sqflite_query.dart';
import 'package:idb_sqflite/src/sqflite_transaction.dart';
import 'package:idb_sqflite/src/sqflite_utils.dart';
import 'package:idb_sqflite/src/sqflite_value.dart';

import 'idb_import.dart';

export 'package:idb_shim/src/common/common_join_query.dart'
    show IdbJoinQuerySupport, IdbJoinRow;

/// Column holding the key the joined row was looked up with.
const joinKeyColumnName = '_jk';

/// Column holding the primary key of the joined row.
const joinedPrimaryKeyColumnName = '_jrk';

/// Column holding the value of the joined row.
const joinedValueColumnName = '_jv';

/// Alias of the joined table.
///
/// Its columns are renamed so that the column names of the iterated table stay
/// unambiguous in the join: a where clause built for a single table (see
/// [SqfliteSelectQuery]) can then be used as is.
const _joinTableAlias = '_j';

/// Alias of the index table the join key is read from, when it is read from an
/// index of the iterated store.
const _sourceIndexAlias = '_bi';

/// A select statement and its arguments.
typedef SqfliteJoinStatement = ({String sql, List<Object> args});

/// Run [statement].
Future<List<Map<String, Object?>>> sqfliteJoinExecute(
  IdbTransactionSqflite? transaction,
  SqfliteJoinStatement statement,
) => transaction!.rawQuery(statement.sql, statement.args);

/// The sqlite json path for [keyPath] (`a.b` giving `$."a"."b"`), null when it
/// cannot be expressed as one.
String? sqliteJsonPath(String keyPath) {
  var parts = keyPath.split('.');
  var sb = StringBuffer(r'$');
  for (var part in parts) {
    if (part.isEmpty || part.contains('"') || part.contains(r'\')) {
      return null;
    }
    sb.write('."$part"');
  }
  return sb.toString();
}

/// Whether the sqlite of this database has the json1 functions, needed to read
/// a join key from a stored value.
///
/// json1 is compiled in by default since sqlite 3.38 only, so an older android
/// system sqlite can be missing it. Probed once per database, in [transaction]
/// so that no other connection is involved.
Future<bool> sqfliteSupportsJsonExtract(
  IdbDatabaseSqflite database,
  IdbTransactionSqflite transaction,
) async {
  var supported = database.supportsJsonExtract;
  if (supported != null) {
    return supported;
  }
  try {
    await transaction.rawQuery(
      "SELECT json_extract('{\"a\":1}', '\$.a')",
      null,
    );
    supported = true;
  } catch (_) {
    supported = false;
  }
  return database.supportsJsonExtract = supported;
}

/// Where a native join reads the join key of the iterated rows.
enum SqfliteJoinKeySource {
  /// The key the iterated table is ordered by: the primary key of a store, the
  /// index key of an index view.
  ownKey,

  /// An index table of the iterated store, joined on the record id.
  ///
  /// Only for a store: it gives the key held by a field without reading, let
  /// alone parsing, the stored value.
  sourceIndex,

  /// The stored value, read with `json_extract`.
  value,
}

/// The iterated side of a native join.
class SqfliteJoinSource {
  /// Create a source.
  SqfliteJoinSource({
    required this.from,
    required this.primaryKeyColumns,
    required this.rangeColumns,
    required this.keySource,
    required this.keyColumn,
    this.indexTable,
    this.jsonPath,
  });

  /// Table or view the rows are read from.
  final String from;

  /// Primary key columns of the iterated record, in [from].
  final List<String> primaryKeyColumns;

  /// Columns the range and the order apply to: the primary key columns of a
  /// store, the index key columns of an index.
  final List<String> rangeColumns;

  /// Where the join key is read.
  final SqfliteJoinKeySource keySource;

  /// Column holding the join key, in [from] or in [indexTable].
  final String keyColumn;

  /// Index table the join key is read from, for
  /// [SqfliteJoinKeySource.sourceIndex].
  final String? indexTable;

  /// Json path of the join key, for [SqfliteJoinKeySource.value].
  final String? jsonPath;

  /// Sql expression of the join key.
  String get keyExpression => switch (keySource) {
    SqfliteJoinKeySource.ownKey => '$from.$keyColumn',
    SqfliteJoinKeySource.sourceIndex => '$_sourceIndexAlias.$keyColumn',
    SqfliteJoinKeySource.value => 'json_extract($from.$valueColumnName, ?)',
  };

  /// Arguments of [keyExpression], repeated wherever it appears.
  List<Object> get keyArguments =>
      keySource == SqfliteJoinKeySource.value ? [jsonPath!] : const [];
}

/// The joined side of a native join.
class SqfliteJoinTarget {
  /// Create a target.
  SqfliteJoinTarget({
    required this.from,
    required this.keyColumn,
    required this.primaryKeyColumn,
  });

  /// Table or view the joined rows are read from: the store table when
  /// joining on its primary key, the index view when joining on an index.
  final String from;

  /// Column the join key is matched against.
  final String keyColumn;

  /// Primary key column of the joined record, in [from].
  final String primaryKeyColumn;
}

/// Run a select resolving the join in sql, so that the joined rows are read in
/// one query instead of one query per distinct join key.
///
/// The columns of the iterated table are returned under their own name, the
/// join key under [joinKeyColumnName], the primary key of the joined row under
/// [joinedPrimaryKeyColumnName] and its value under [joinedValueColumnName].
///
/// [joinAlwaysNeeded] is for a target matching any number of rows: the number
/// of matches is then the number of rows, so the join has to be resolved even
/// when neither side of it is read.
Future<List<Map<String, Object?>>> sqfliteJoinedRows({
  required IdbTransactionSqflite? transaction,
  required SqfliteJoinSource source,
  required SqfliteJoinTarget target,
  KeyRange? range,
  String? direction,
  int? offset,
  int? limit,
  bool inner = false,
  bool withValue = true,
  bool withJoinedValue = true,
  bool joinAlwaysNeeded = false,
}) => sqfliteJoinExecute(
  transaction,
  sqfliteJoinStatement(
    source: source,
    target: target,
    range: range,
    direction: direction,
    offset: offset,
    limit: limit,
    inner: inner,
    withValue: withValue,
    withJoinedValue: withJoinedValue,
    joinAlwaysNeeded: joinAlwaysNeeded,
  ),
);

/// The statement [sqfliteJoinedRows] runs.
///
/// Split out so that a test can check the query plan of the very statement
/// that is run: a plan that stops using an index is still correct, only much
/// slower.
SqfliteJoinStatement sqfliteJoinStatement({
  required SqfliteJoinSource source,
  required SqfliteJoinTarget target,
  KeyRange? range,
  String? direction,
  int? offset,
  int? limit,
  bool inner = false,
  bool withValue = true,
  bool withJoinedValue = true,
  bool joinAlwaysNeeded = false,
}) {
  direction ??= idbDirectionNext;

  // Only there to build the where clause and its arguments of the iterated
  // table, the select itself is built below.
  var query = SqfliteSelectQuery(
    source.rangeColumns,
    source.from,
    source.rangeColumns,
    range,
    direction,
  )..buildParameters();

  var joinKeySql = source.keyExpression;
  // Matching at most one row, the join only has to be resolved when the
  // caller wants the joined value, or when an inner join drops the rows that
  // have none.
  var needJoin = withJoinedValue || inner || joinAlwaysNeeded;
  var joinType = inner ? 'INNER JOIN' : 'LEFT JOIN';

  var sb = StringBuffer();
  var args = <Object>[];

  sb.write('SELECT ');
  sb.write(
    [
      ...source.primaryKeyColumns.map((column) => '${source.from}.$column'),
      if (withValue) '${source.from}.$valueColumnName',
      '$joinKeySql AS $joinKeyColumnName',
      if (needJoin) ...[
        '$_joinTableAlias.$joinedPrimaryKeyColumnName',
        if (withJoinedValue) '$_joinTableAlias.$joinedValueColumnName',
      ],
    ].join(', '),
  );
  args.addAll(source.keyArguments);

  sb.write(' FROM ${source.from}');

  if (source.keySource == SqfliteJoinKeySource.sourceIndex) {
    // An inner join drops the records with no index row, i.e. no join key,
    // which is what it would drop anyway for having no joined row.
    sb.write(' $joinType ${source.indexTable} AS $_sourceIndexAlias');
    // The unary + is what makes this use the index on the record id column.
    // The column is declared BLOB (no affinity) while rowid has integer
    // affinity, so sqlite would apply numeric affinity to the indexed column
    // before comparing, and an index cannot be used through a conversion. The
    // unary + is a no-op on the value that drops the affinity of the rowid
    // side, leaving both sides unconverted. Without it the query is still
    // correct, sqlite just scans the index table for every record.
    sb.write(
      ' ON $_sourceIndexAlias.$primaryIdColumnName'
      ' = +${source.from}.$sqliteRowId',
    );
  }

  if (needJoin) {
    sb.write(' $joinType');
    sb.write(
      ' (SELECT ${target.keyColumn} AS $joinKeyColumnName'
      ', ${target.primaryKeyColumn} AS $joinedPrimaryKeyColumnName'
      ', $valueColumnName AS $joinedValueColumnName'
      ' FROM ${target.from}) AS $_joinTableAlias',
    );
    sb.write(' ON $_joinTableAlias.$joinKeyColumnName = $joinKeySql');
    args.addAll(source.keyArguments);
  }

  var where = query.sqlWhere;
  if (where != null) {
    sb.write(' WHERE $where');
    args.addAll(query.sqlWhereArgs!);
  }

  // Ordered by the range columns only, like every other query of this
  // implementation: two records can share an index key, and the order of such
  // a tie is left to sqlite rather than forced with the primary key, which
  // would cost a sort (the index gives the key order, not the primary key
  // order within a key).
  var order = direction == idbDirectionPrev ? 'DESC' : 'ASC';
  sb.write(
    ' ORDER BY '
    '${source.rangeColumns.map((column) => '${source.from}.$column $order').join(', ')}',
  );

  // sqlite ignores OFFSET without a LIMIT, -1 means no limit.
  if (limit != null || (offset ?? 0) > 0) {
    sb.write(' LIMIT ${limit ?? -1}');
    if ((offset ?? 0) > 0) {
      sb.write(' OFFSET $offset');
    }
  }

  return (sql: sb.toString(), args: args);
}

/// An [IdbJoinRow] from one row of [sqfliteJoinedRows].
///
/// [primaryKey] is read by the caller, which knows the primary key columns of
/// the iterated store.
IdbJoinRow sqfliteJoinRowOf(
  Map<String, Object?> row, {
  required Object primaryKey,
  required bool withValue,
}) {
  var rawJoinedValue = row[joinedValueColumnName];
  return IdbJoinRow(
    primaryKey: primaryKey,
    value: withValue
        ? fromSqfliteValue(decodeValue(row[valueColumnName])!)
        : null,
    joinKey: row[joinKeyColumnName],
    joinedPrimaryKey: row[joinedPrimaryKeyColumnName],
    joinedValue: rawJoinedValue == null
        ? null
        : fromSqfliteValue(decodeValue(rawJoinedValue)!),
  );
}
