// ignore_for_file: implementation_imports
import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/src/common/common_meta.dart';
import 'package:idb_shim/src/common/common_validation.dart';
import 'package:idb_shim/src/common/common_value.dart';
import 'package:idb_sqflite/src/sqflite_cursor.dart';
import 'package:idb_sqflite/src/sqflite_object_store.dart';
import 'package:idb_sqflite/src/sqflite_query.dart';
import 'package:idb_sqflite/src/sqflite_transaction.dart';
import 'package:idb_sqflite/src/sqflite_utils.dart';
import 'package:meta/meta.dart';
import 'package:sqflite/sqlite_api.dart' as sqflite;

class IdbIndexSqflite with IndexWithMetaMixin implements Index {
  IdbIndexSqflite(this.store, this.meta);

  IdbObjectStoreSqflite store;
  @override
  final IdbIndexMeta meta;

  String get sqlIndexTableName => '${store.name}__$name';
  //String get sqlIndexName => sqlIndexTableName;
  // join view name
  String get sqlIndexViewName => '${sqlIndexTableName}__j';
  String get sqlStoreTableName => store.sqlTableName;
  String get sqlKeyIndexName => '${sqlIndexTableName}__k';
  String get sqlPrimaryKeyIndexName => '${sqlIndexTableName}__pk';

  String keyColumnNameToSqlIndexName(String keyColumnName) =>
      '${sqlIndexTableName}__$keyColumnName';

  // Ordered keys
  final keys = <dynamic>[];

  /// true if keyPath is an array
  bool get isMultiKey => keyPath is List;
  int get multiKeyCount => (keyPath as List).length;

  IdbTransactionSqflite get transaction => store.transaction;

  // either 'k', or 'k1, k2, k3...'
  List<String> get keyColumnNames => isMultiKey
      ? List.generate(multiKeyCount, (i) => keyIndexToKeyName(i))
      : [keyColumnName];
  Future create() async {
    if (multiEntry && isMultiKey) {
      throw UnsupportedError(
          'Having multiEntry and multiKey path is not supported');
    }

    // For multi entry we create a new table instead of an index
    await transaction.batch((batch) {
      var tableName = sqlIndexTableName;
      batch.execute('CREATE TABLE $tableName ('
          // key BLOB or key1 BLOB, key2 BLOB...
          '${keyColumnNames.map((name) => '$name BLOB').join(', ')}, '
          '$primaryIdColumnName BLOB)');
      // 'FOREIGN KEY ($primaryIdColumnName) REFERENCES $sqlStoreTableName($sqliteRowId) ON DELETE CASCADE)');

      batch.execute(
          'CREATE VIEW $sqlIndexViewName AS SELECT ${keyColumnNames.join(', ')}, $primaryKeyColumnName, $valueColumnName '
          'FROM $tableName INNER JOIN $sqlStoreTableName ON $tableName.$primaryIdColumnName = $sqlStoreTableName.$sqliteRowId');
      if (isMultiKey) {
        // Create index on each key
        for (int i = 0; i < multiKeyCount; i++) {
          var keyColumnName = keyIndexToKeyName(i);
          batch.execute(
              'CREATE INDEX ${keyColumnNameToSqlIndexName(keyColumnName)} ON $tableName ($keyColumnName)');
        }
      }
      // Create index on all keys
      var sb = StringBuffer();
      sb.write("CREATE ");
      if (unique) {
        sb.write("UNIQUE ");
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
      String tableName = sqlIndexTableName;
      var query = SqfliteCountQuery(tableName, keyColumnNames, keyOrKeyRange);
      return query.count(transaction);
    });
  }

  @override
  Future get(key) {
    checkKeyParam(key);
    return _checkIndex(() async {
      var row = await getFirstRow(key, columns: [valueColumnName]);
      if (row == null) {
        return null;
      }
      return store.valueRowToRecord(
          row[primaryKeyColumnName], row[valueColumnName]);
    });
  }

  /// Returns null if not found
  Future<Map<String, dynamic>> getFirstRow(dynamic key,
      {@required List<String> columns}) async {
    var rows = await transaction.query(sqlIndexViewName,
        columns: columns,
        where: '${keyColumnNames.map((name) => '$name = ?').join(' AND ')}',
        whereArgs: itemOrItemsToList(key),
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
      var row = await getFirstRow(key, columns: [primaryKeyColumnName]);
      if (row == null) {
        return null;
      }
      var primaryKey = decodeKey(row.values?.first);
      return primaryKey;
    });
  }

  @override
  Stream<Cursor> openKeyCursor(
      {key, KeyRange range, String direction, bool autoAdvance}) {
    var ctlr = IdbIndexKeyCursorControllerSqflite(this, direction, autoAdvance);

    // Future
    _checkIndex(() {
      return ctlr.execute(key, range);
    });
    return ctlr.stream;
  }

  @override
  Stream<CursorWithValue> openCursor(
      {key, KeyRange range, String direction, bool autoAdvance}) {
    var ctlr =
        IdbIndexCursorWithValueControllerSqflite(this, direction, autoAdvance);

    // Future
    _checkIndex(() {
      return ctlr.execute(key, range);
    });
    return ctlr.stream;
  }

  Future insertKey(int primaryId, dynamic keyValue) async {
    await transaction.batch((batch) {
      insertKeyBatch(batch, primaryId, keyValue);
    });
  }

  void insertKeyBatch(sqflite.Batch batch, int primaryId, dynamic keyValue) {
    if (keyValue != null) {
      if (multiEntry) {
        var keys = valueAsSet(keyValue);
        if (keys?.isNotEmpty ?? false) {
          for (var key in keys) {
            key = encodeKey(key);
            var map = <String, dynamic>{
              primaryIdColumnName: primaryId,
              keyColumnName: key
            };
            batch.insert(sqlIndexTableName, map);
          }
        }
      } else {
        var map = <String, dynamic>{primaryIdColumnName: primaryId};
        if (isMultiKey) {
          assert(keyValue is List && keyValue.length == multiKeyCount);
          // Create index on each key plus one for all
          for (int i = 0; i < multiKeyCount; i++) {
            var keyColumnName = keyIndexToKeyName(i);
            map[keyColumnName] = encodeKey((keyValue as List)[i]);
          }
        } else {
          map[keyColumnName] = encodeKey(keyValue);
        }
        batch.insert(sqlIndexTableName, map);
      }
    }
  }

  Future updateKey(int primaryId, dynamic keyValue) async {
    await transaction.batch((batch) {
      batch.delete(sqlIndexTableName,
          where: '$primaryIdColumnName = ?', whereArgs: [primaryId]);
      insertKeyBatch(batch, primaryId, keyValue);
    });
  }

  Future deleteKey(int primaryId) async {
    await transaction.batch((batch) {
      batch.delete(sqlIndexTableName,
          where: '$primaryIdColumnName = ?', whereArgs: [primaryId]);
    });
  }
}
