// ignore_for_file: unnecessary_string_interpolations

import 'package:idb_shim/idb_client.dart';

import 'package:idb_sqflite/src/sqflite_error.dart';
import 'package:idb_sqflite/src/sqflite_transaction.dart';
import 'package:idb_sqflite/src/sqflite_utils.dart';
import 'package:sqflite_common/utils/utils.dart';

import 'idb_import.dart';

/// Sql query
class SqfliteQuery {
  /// Sql query
  late String sqlStatement;

  /// Sql arguments
  List<Object>? arguments;
}

const String _sqlCountColumnName = '_COUNT';
const _sqlCount = 'COUNT(*) AS $_sqlCountColumnName';

/// Sql where clause matching nothing.
const _sqlFalse = '1 = 0';

/// The sql argument of a key stored in a single column.
///
/// Throws a DataError for an array key (only the items of an array key path
/// are stored, one per column).
Object sqfliteColumnKey(Object key) {
  if (sqfliteIsArrayKey(key)) {
    throw sqfliteArrayKeyError(key);
  }
  return encodeKey(key);
}

/// The sql value of a key stored in an index column.
///
/// A `List<int>` is still stored as a blob (as before 1.5.1, sorting after the
/// strings like an array), other arrays throw a DataError.
Object sqfliteIndexColumnKey(Object key) {
  if (key is List<int>) {
    return key;
  }
  return sqfliteColumnKey(key);
}

/// Where clause matching [key] in [keyColumns], its arguments added to
/// [args].
///
/// [compositeKey] is true when [keyColumns] hold the items of an array key
/// path, [integerKeys] when they are the INTEGER PRIMARY KEY of an
/// autoIncrement store (which converts a text argument to a number, so only
/// numbers can match).
String sqfliteKeyEqualsWhere(
  List<String> keyColumns,
  Object key,
  List<Object> args, {
  required bool compositeKey,
  bool integerKeys = false,
}) {
  List<Object> values;
  if (compositeKey) {
    // A single key or an array of another length is never equal.
    if (!sqfliteIsArrayKey(key) || (key as List).length != keyColumns.length) {
      return _sqlFalse;
    }
    values = _compositeKeyItems(key);
  } else {
    var value = sqfliteColumnKey(key);
    if (integerKeys && value is! num) {
      return _sqlFalse;
    }
    values = [value];
  }
  args.addAll(values);
  return keyColumns.map((column) => '$column = ?').join(' AND ');
}

/// The sql arguments of the items of an array key, one per column.
List<Object> _compositeKeyItems(List key) =>
    key.map((item) => sqfliteColumnKey(item as Object)).toList();

/// Select query
class SqfliteSelectQuery extends SqfliteQuery {
  /// Select query
  SqfliteSelectQuery(
    this.columns,
    this._sqlTableName,
    this.keyColumns, //
    this.keyOrKeyRange,
    this._direction, {
    this.limit,
    this.offset,
    this.primaryKeyColumns,
    this.compositeKey = false,
    this.integerKeys = false,
  });

  /// Select of `getAll` and `getAllKeys`, in key order: a [count] of 0 (or
  /// null) means no limit, like IndexedDB.
  SqfliteSelectQuery.getAll(
    List<String> columns,
    String sqlTableName,
    List<String> keyColumns,
    Object? query,
    int? count, {
    List<String>? primaryKeyColumns,
    bool compositeKey = false,
    bool integerKeys = false,
  }) : this(
         columns,
         sqlTableName,
         keyColumns,
         query,
         idbDirectionNext,
         limit: (count ?? 0) > 0 ? count : null,
         primaryKeyColumns: primaryKeyColumns,
         compositeKey: compositeKey,
         integerKeys: integerKeys,
       );

  /// Columns
  List<String> columns;
  final String _sqlTableName;

  /// key or key range
  Object? keyOrKeyRange;
  final String? _direction;

  /// key columns
  List<String> keyColumns;

  /// Primary key columns of an index query, ordering the rows sharing the
  /// same index key (by primary key, like IndexedDB, in the same direction).
  ///
  /// null for a store query, the key columns being the primary key already.
  final List<String>? primaryKeyColumns;

  /// True when [keyColumns] hold the items of an array key path.
  final bool compositeKey;

  /// True when [keyColumns] is the INTEGER PRIMARY KEY of an autoIncrement
  /// store: only number keys and bounds are compared to it.
  final bool integerKeys;

  /// limit
  final int? limit;

  /// offset, only meaningful with a [limit] for sqlite, a limit of -1 is
  /// used when only an offset is given.
  final int? offset;
  // Build during buildParameters
  String? _orderBy;

  /// Built during buildParameters
  String? sqlWhere;

  /// Built during buildParameters
  List<Object>? sqlWhereArgs;

  /// Build the parameters
  void buildParameters() {
    String? order;

    if (_direction != null) {
      switch (_direction) {
        case idbDirectionNext:
          order = 'ASC';
          break;
        case idbDirectionPrev:
          order = 'DESC';
          break;

        default:
          throw ArgumentError("direction '$_direction' not supported");
      }
    }
    var args = <Object>[];
    String? where;

    var keyOrKeyRange = this.keyOrKeyRange;
    if (keyOrKeyRange is KeyRange) {
      where = _rangeWhere(keyOrKeyRange, args);
    } else if (keyOrKeyRange != null) {
      where = sqfliteKeyEqualsWhere(
        keyColumns,
        keyOrKeyRange,
        args,
        compositeKey: compositeKey,
        integerKeys: integerKeys,
      );
    } else {
      // Not null needed for index key
      // Not it using pk[1] but using k1, k2...
      if (keyColumns.isNotEmpty &&
          !keyColumns.first.startsWith(primaryKeyColumnName)) {
        where = keyColumns.map((column) => '$column NOT NULL').join(' AND ');
      }
    }

    // order not needed for COUNT(*)
    if (order != null) {
      _orderBy = [
        ...keyColumns,
        ...?primaryKeyColumns,
      ].map((column) => '$column $order').join(', ');
    }
    sqlWhere = where;
    sqlWhereArgs = args;
  }

  /// Where clause of a key range, null when it matches every key.
  String? _rangeWhere(KeyRange keyRange, List<Object> args) {
    var lowerArgs = <Object>[];
    var upperArgs = <Object>[];
    var lower = keyRange.lower == null
        ? null
        : _boundWhere(
            keyRange.lower as Object,
            open: keyRange.lowerOpen,
            lower: true,
            args: lowerArgs,
          );
    var upper = keyRange.upper == null
        ? null
        : _boundWhere(
            keyRange.upper as Object,
            open: keyRange.upperOpen,
            lower: false,
            args: upperArgs,
          );
    if (lower == _sqlFalse || upper == _sqlFalse) {
      return _sqlFalse;
    }
    args
      ..addAll(lowerArgs)
      ..addAll(upperArgs);
    if (lower == null) {
      return upper;
    } else if (upper == null) {
      return lower;
    }
    return '($lower) AND ($upper)';
  }

  /// Where clause of a [lower] (or upper) bound, null when every key is in
  /// range, [_sqlFalse] when none is.
  ///
  /// The bound is compared to the key columns like IndexedDB: an array bound
  /// item by item then by length, an array key is after any other key, and
  /// numbers are before strings (then binaries).
  String? _boundWhere(
    Object bound, {
    required bool open,
    required bool lower,
    required List<Object> args,
  }) {
    var columnCount = keyColumns.length;
    List<Object> values;
    if (compositeKey) {
      // Every array key is after a single key.
      if (!sqfliteIsArrayKey(bound)) {
        return lower ? null : _sqlFalse;
      }
      values = _compositeKeyItems(bound as List);
      if (values.length < columnCount) {
        // A key starting with the bound is after it (it is longer).
        open = !lower;
      } else if (values.length > columnCount) {
        // A key equal to the start of the bound is before it (it is shorter).
        values = values.sublist(0, columnCount);
        open = lower;
      }
      if (values.isEmpty) {
        // Every array key is after the empty array.
        return lower ? null : _sqlFalse;
      }
    } else {
      var value = sqfliteColumnKey(bound);
      // Every number is before a string or a binary.
      if (integerKeys && value is! num) {
        return lower ? _sqlFalse : null;
      }
      values = [value];
    }
    return _lexicographicWhere(values, open: open, lower: lower, args: args);
  }

  /// (k1 > ?) OR (k1 = ? AND (k2 >= ?)) for the first key columns.
  String _lexicographicWhere(
    List<Object> values, {
    required bool open,
    required bool lower,
    required List<Object> args,
  }) {
    var operator = lower ? '>' : '<';
    var sb = StringBuffer();
    for (var i = 0; i < values.length; i++) {
      var column = keyColumns[i];
      var value = values[i];

      // last
      if (i == values.length - 1) {
        sb.write(open ? '$column $operator ?' : '$column $operator= ?');
        args.add(value);
      } else {
        sb.write('($column $operator ?) OR ($column = ? AND (');
        args.addAll([value, value]);
      }
    }

    // close parenthesis
    for (var i = 1; i < values.length; i++) {
      sb.write('))');
    }
    return sb.toString();
  }

  /// Execute the query
  Future<List<Map<String, Object?>>> execute(
    IdbTransactionSqflite? transaction,
  ) {
    buildParameters();

    //var sqlArgs = [encodeKey(key)];
    return transaction!.query(
      _sqlTableName,
      columns: columns,
      where: sqlWhere,
      whereArgs: sqlWhereArgs,
      orderBy: _orderBy,
      // sqlite ignores OFFSET without a LIMIT, -1 means no limit.
      limit: limit ?? ((offset ?? 0) > 0 ? -1 : null),
      offset: offset,
    );
  }
}

/// Count query
class SqfliteCountQuery extends SqfliteSelectQuery {
  /// Count query
  SqfliteCountQuery(
    String sqlTableName,
    List<String> keyColumns,
    Object? keyOrKeyRange, {
    super.compositeKey,
    super.integerKeys,
  }) //
  : super([_sqlCount], sqlTableName, keyColumns, keyOrKeyRange, null);

  /// Count
  Future<int> count(IdbTransactionSqflite? transaction) async {
    var rows = await execute(transaction);
    return firstIntValue(rows)!;
  }
}
