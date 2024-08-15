// ignore_for_file: implementation_imports, unnecessary_string_interpolations
import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/src/common/common_meta.dart';
import 'package:idb_shim/src/common/common_validation.dart';
import 'package:idb_shim/src/common/common_value.dart';
import 'package:idb_sqflite/src/sqflite_cursor.dart';
import 'package:idb_sqflite/src/sqflite_key_path.dart';
import 'package:idb_sqflite/src/sqflite_object_store.dart';
import 'package:idb_sqflite/src/sqflite_query.dart';
import 'package:idb_sqflite/src/sqflite_transaction.dart';
import 'package:idb_sqflite/src/sqflite_utils.dart';
import 'package:idb_sqflite/src/sqflite_value.dart';
import 'package:sqflite_common/sqlite_api.dart' as sqflite;

/// Index implementation
class IdbIndexSqflite
    with IdbSqfliteKeyPathMixin, IndexWithMetaMixin
    implements Index {
  /// Index implementation
  IdbIndexSqflite(this.store, this.meta);

  @override
  Object? get primaryKeyPath => store.primaryKeyPath;

  /// Store
  IdbObjectStoreSqflite store;
  @override
  final IdbIndexMeta meta;

  /// index table name
  String get sqlIndexTableName => '${store.name}__$name';

  //String get sqlIndexName => sqlIndexTableName;
  // join view name
  /// index view name
  String get sqlIndexViewName => '${sqlIndexTableName}__j';

  /// Store table name
  String get sqlStoreTableName => store.sqlTableName;

  /// key index name
  String get sqlKeyIndexName => '${sqlIndexTableName}__k';

  /// primary key index name
  String get sqlPrimaryKeyIndexName => '${sqlIndexTableName}__pk';

  /// key column name to sql index name
  String keyColumnNameToSqlIndexName(String keyColumnName) =>
      '${sqlIndexTableName}__$keyColumnName';

  /// Ordered keys
  final keys = <dynamic>[];

  /// Transaction
  IdbTransactionSqflite? get transaction => store.transaction;

  /// Create the index
  Future<void> create() async {
    if (multiEntry && isCompositeKey) {
      throw UnsupportedError(
          'Having multiEntry and multiKey path is not supported');
    }

    // For multi entry we create a new table instead of an index
    await transaction!.batch((batch) {
      var tableName = sqlIndexTableName;
      batch.execute('CREATE TABLE $tableName ('
          // key BLOB or key1 BLOB, key2 BLOB...
          '${keyColumnNames.map((name) => '$name BLOB').join(', ')}, '
          '$primaryIdColumnName BLOB)');
      // 'FOREIGN KEY ($primaryIdColumnName) REFERENCES $sqlStoreTableName($sqliteRowId) ON DELETE CASCADE)');

      batch.execute(
          'CREATE VIEW $sqlIndexViewName AS SELECT ${keyColumnNames.join(', ')}, ${primaryKeyColumnNames.join(', ')}, $valueColumnName '
          'FROM $tableName INNER JOIN $sqlStoreTableName ON $tableName.$primaryIdColumnName = $sqlStoreTableName.$sqliteRowId');
      if (isCompositeKey) {
        // Create index on each key
        for (var i = 0; i < compositeKeyCount; i++) {
          var keyColumnName = keyIndexToKeyName(i);
          batch.execute(
              'CREATE INDEX ${keyColumnNameToSqlIndexName(keyColumnName)} ON $tableName ($keyColumnName)');
        }
      }
      // Create index on all keys
      var sb = StringBuffer();
      sb.write('CREATE ');
      if (unique) {
        sb.write('UNIQUE ');
      }
      sb.write(
          'INDEX ${keyColumnNameToSqlIndexName(keyColumnName)} ON $tableName '
          // (k) or (k1, k2)
          '(${keyColumnNames.join(', ')})');

      batch.execute(sb.toString());

      // ...and on the couple key/primaryKey

      batch.execute(
          'CREATE INDEX ${keyColumnNameToSqlIndexName(primaryIdColumnName)} ON $tableName (${keyColumnNames.join(', ')}, $primaryIdColumnName)');
    });
  }

  /// Drop the index
  void drop(sqflite.Batch batch) {
    batch.execute('DROP TABLE IF EXISTS $sqlIndexTableName');
    batch.execute('DROP VIEW IF EXISTS $sqlIndexViewName');
  }

  Future<T> _checkIndex<T>(Future<T> Function() computation) {
    return store.checkStore(computation);
  }

  @override
  Future<int> count([keyOrKeyRange]) {
    return _checkIndex(() {
      var tableName = sqlIndexTableName;
      var query = SqfliteCountQuery(tableName, keyColumnNames, keyOrKeyRange);
      return query.count(transaction);
    });
  }

  @override
  Future get(Object key) {
    checkKeyParam(key);
    return _checkIndex(() async {
      var row = await getFirstRow(key,
          columns: [...primaryKeyColumnNames, valueColumnName]);
      if (row == null) {
        return null;
      }
      return store.valueRowToRecord(
          store.rowGetPrimaryKeyValue(row), row[valueColumnName]!);
    });
  }

  /// Returns null if not found
  Future<Map<String, Object?>?> getFirstRow(Object key,
      {List<String>? columns}) async {
    var condition = KeyPathWhere.keyEquals(this, key);
    var rows = await transaction!.query(sqlIndexViewName,
        columns: columns,
        where: condition.where,
        whereArgs: condition.whereArgs,
        limit: 1);
    if (rows.isEmpty) {
      return null;
    }
    return rows.first;
  }

  // Get the primary key
  @override
  Future getKey(key) {
    checkKeyParam(key);
    if (key is KeyRange) {
      throw UnsupportedError('Index.getKey(keyRange) not supported');
    }
    return _checkIndex(() async {
      var row = await getFirstRow(key, columns: store.primaryKeyColumnNames);
      if (row == null) {
        return null;
      }
      var primaryKey = decodeKey(row.values.first!);
      return primaryKey;
    });
  }

  @override
  Stream<Cursor> openKeyCursor(
      {key, KeyRange? range, String? direction, bool? autoAdvance}) {
    var ctlr = IdbIndexKeyCursorControllerSqflite(
        this, direction ?? idbDirectionNext, autoAdvance ?? false);

    checkOpenCursorArguments(key, range);
    // Future
    _checkIndex(() {
      return ctlr.execute(key, range);
    });
    return ctlr.stream;
  }

  @override
  Stream<CursorWithValue> openCursor(
      {key, KeyRange? range, String? direction, bool? autoAdvance}) {
    var ctlr = IdbIndexCursorWithValueControllerSqflite(
        this, direction ?? idbDirectionNext, autoAdvance ?? false);

    checkOpenCursorArguments(key, range);

    // Future
    _checkIndex(() {
      return ctlr.execute(key, range);
    });
    return ctlr.stream;
  }

  /// Insert a key
  Future insertKey(int primaryId, dynamic keyValue) async {
    await transaction!.batch((batch) {
      insertKeyBatch(batch, primaryId, keyValue);
    });
  }

  /// Insert a key in a batch
  void insertKeyBatch(sqflite.Batch batch, int? primaryId, dynamic keyValue) {
    if (keyValue != null) {
      if (multiEntry) {
        var keys = valueAsSet(keyValue);
        if (keys?.isNotEmpty ?? false) {
          for (var key in keys!) {
            key = encodeKey(key!);
            var map = <String, Object?>{
              primaryIdColumnName: primaryId,
              keyColumnName: key
            };
            batch.insert(sqlIndexTableName, map);
          }
        }
      } else {
        var map = <String, Object?>{primaryIdColumnName: primaryId};
        if (isCompositeKey) {
          assert(keyValue is List && keyValue.length == compositeKeyCount);
          // Create index on each key plus one for all
          for (var i = 0; i < compositeKeyCount; i++) {
            var keyColumnName = keyIndexToKeyName(i);
            // Can be null
            map[keyColumnName] = _encodeKeyOrNull((keyValue as List)[i]);
          }
        } else {
          map[keyColumnName] = encodeKey(keyValue as Object);
        }
        batch.insert(sqlIndexTableName, map);
      }
    }
  }

  Object? _encodeKeyOrNull(Object? key) {
    if (key == null) {
      return null;
    }
    return encodeKey(key);
  }

  /// Update a key
  Future updateKey(int primaryId, dynamic keyValue) async {
    await transaction!.batch((batch) {
      batch.delete(sqlIndexTableName,
          where: '$primaryIdColumnName = ?', whereArgs: [primaryId]);
      insertKeyBatch(batch, primaryId, keyValue);
    });
  }

  /// Delete a key
  Future deleteKey(int primaryId) async {
    await transaction!.batch((batch) {
      batch.delete(sqlIndexTableName,
          where: '$primaryIdColumnName = ?', whereArgs: [primaryId]);
    });
  }

  @override
  Future<List<Object>> getAll([dynamic query, int? count]) {
    return _checkIndex(() {
      var tableName = sqlIndexViewName;
      var columns = [valueColumnName];
      var keyColumnNames = this.keyColumnNames;
      var selectQuery = SqfliteSelectQuery(
          columns, tableName, keyColumnNames, query, idbDirectionNext,
          limit: count);
      return selectQuery.execute(transaction).then((rs) {
        return rs
            .map((row) =>
                fromSqfliteValue(decodeValue(row[valueColumnName] as Object)!))
            .toList(growable: false);
      });
    });
  }

  @override
  Future<List<Object>> getAllKeys([query, int? count]) {
    return _checkIndex(() {
      var tableName = sqlIndexViewName;
      var columns = primaryKeyColumnNames;
      var keyColumnNames = this.keyColumnNames;
      var selectQuery = SqfliteSelectQuery(
          columns, tableName, keyColumnNames, query, idbDirectionNext,
          limit: count);
      return selectQuery.execute(transaction).then((rs) {
        return rs
            .map((row) => rowGetPrimaryKeyValue(row))
            .toList(growable: false);
      });
    });
  }
}
