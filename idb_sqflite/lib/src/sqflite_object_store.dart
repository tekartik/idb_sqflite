// ignore_for_file: implementation_imports
import 'dart:convert';

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/src/common/common_meta.dart';
import 'package:idb_shim/src/common/common_validation.dart';
import 'package:idb_shim/src/common/common_value.dart';
import 'package:idb_sqflite/src/sqflite_constant.dart';
import 'package:idb_sqflite/src/sqflite_cursor.dart';
import 'package:idb_sqflite/src/sqflite_database.dart';
import 'package:idb_sqflite/src/sqflite_error.dart';
import 'package:idb_sqflite/src/sqflite_index.dart';
import 'package:idb_sqflite/src/sqflite_key_path.dart';
import 'package:idb_sqflite/src/sqflite_query.dart';
import 'package:idb_sqflite/src/sqflite_transaction.dart';
import 'package:idb_sqflite/src/sqflite_utils.dart';
import 'package:idb_sqflite/src/sqflite_value.dart';

import 'core_imports.dart';

/// Object store implementation
class IdbObjectStoreSqflite
    with IdbSqfliteKeyPathMixin, ObjectStoreWithMetaMixin
    implements ObjectStore {
  /// Object store implementation
  IdbObjectStoreSqflite(this.transaction, this.meta);

  /// Database
  IdbDatabaseSqflite get database => transaction.database as IdbDatabaseSqflite;

  /// default column name
  static const String keyDefaultColumnName = primaryKeyColumnName;

  /// Transaction
  final IdbTransactionSqflite transaction;

  @override
  final IdbObjectStoreMeta? meta;

  /*
  _WebSqlDatabase get database => transaction.database;

  bool get ready => keyColumn != null;

   */
  Future? _lazyPrepare;

  @override
  Object? get primaryKeyPath => keyPath;

  /// sql column name
  String sqlColumnName(String? keyPath) {
    if (keyPath == null) {
      return keyDefaultColumnName;
    } else {
      return '_col_${wrapKeyPath(keyPath)}';
    }
  }

  /// sql table name
  String get sqlTableName {
    return getSqlTableName(name);
  }

  /// sql table name from store name
  static String getSqlTableName(String storeName) {
    return 's__$storeName';
  }

  /// Delete the store table
  Future<void> deleteTable(IdbTransactionSqflite transaction) {
    return transaction.batch((batch) {
      batch.execute('DROP TABLE IF EXISTS $sqlTableName');
      // Drop index tables too
      for (var index in _indecies) {
        index.drop(batch);
      }
    });
  }

  /// Update the store table
  Future<void> update() async {
    var metaText = jsonEncode(meta!.toMap());
    await transaction.update(
      storesTable,
      {metaField: metaText},
      where: '$nameField = ?',
      whereArgs: [name],
    );
  }

  /// Create the store table.
  Future<void> create() async {
    var sb = StringBuffer();

    /// Create store table.
    /// CREATE TABLE s__test_store (pk INTEGER PRIMARY KEY AUTOINCREMENT, v BLOB)
    /// CREATE TABLE s__test_store (pk BLOB PRIMARY KEY, v BLOB)
    ///
    /// or
    /// CREATE TABLE s__test_store (pk1 BLOB, pk2 BLOB, v BLOB)
    sb.write('CREATE TABLE $sqlTableName (');
    if (autoIncrement) {
      sb.write('$primaryKeyColumnName INTEGER PRIMARY KEY AUTOINCREMENT');
    } else {
      if (isCompositeKey) {
        sb.write(
          primaryKeyColumnNames.map((e) => '$e BLOB NOT NULL').join(', '),
        );
      } else {
        sb.write('$primaryKeyColumnName BLOB PRIMARY KEY');
      }
    }
    sb.write(', $valueColumnName BLOB)');
    var createSql = sb.toString();

    var metaText = jsonEncode(meta!.toMap());

    var txn = transaction;
    await txn.batch((batch) {
      batch.execute('DROP TABLE IF EXISTS $sqlTableName');
      batch.execute(createSql);
      batch.insert(storesTable, <String, Object?>{
        nameField: name,
        metaField: metaText,
      });

      if (isCompositeKey) {
        batch.execute(
          'CREATE INDEX $compositePrimateKeyIndexName ON $sqlTableName (${primaryKeyColumnNames.join(', ')})',
        );
      }
    });
  }

  /// sql index name
  String get compositePrimateKeyIndexName =>
      '${sqlTableName}__$primaryKeyColumnName';

  Future<T> _checkWritableStore<T>(Future<T> Function() computation) {
    if (transaction.meta!.mode != idbModeReadWrite) {
      return Future.error(DatabaseReadOnlyError());
    }
    return checkStore(computation);
  }

  IdbIndexSqflite? _getIndex(String name) {
    var indexMeta = meta!.index(name);
    return IdbIndexSqflite(this, indexMeta);
  }

  // Don't make it async as it must run before completed is called
  /// Check the store is ready
  Future<T> checkStore<T>(Future<T> Function() computation) async {
    // this is also an indicator
    //if (!ready) {
    // Make sure the db was not upgrade
    // TODO do this at the beginning of each transaction

    // More complex during open, the user might start reading a freshly created
    // store so let's support that by applying schema changes progressively
    if (transaction is IdbOpenTransactionSqflite) {
      await database.applySchemaChanges(
        transaction as IdbOpenTransactionSqflite,
      );
    }

    _lazyPrepare ??= transaction
        .query(
          versionTable,
          columns: [versionField],
          where: '$versionField > ?',
          whereArgs: [database.version],
        ) // TODO investigate why null in put_read_in_open_transaction
        .then((list) async {
          if (list.isNotEmpty) {
            // Send an onVersionChange event
            //Map map = rs.rows.first; - BUG dart, first is null:
            Map map = list.first;
            var newVersion = map[versionField] as int?;
            if (database.onVersionChangeCtlr != null) {
              database.onVersionChangeCtlr!.add(
                IdbVersionChangeEventSqflite(
                  database,
                  database.version,
                  newVersion!,
                ),
              );
            }
            throw StateError(
              'database upgraded from ${database.version} to $newVersion',
            );
          }
        });

    return _lazyPrepare!.then((_) {
      return computation();
    });
  }

  // Convenient access to all indecies
  Iterable<IdbIndexSqflite> get _indecies =>
      meta!.indecies.map((meta) => IdbIndexSqflite(this, meta));

  /// Add a record
  Future<Object> addImpl(Object value, [Object? key]) async {
    Map? mapValue;
    if (value is Map) {
      if (keyPath != null && _getInlineKey(value) == null) {
        mapValue = cloneMap(value);
      } else {
        mapValue = value;
      }
    }
    var map = <String, Object?>{valueColumnName: encodeValue(value)};
    if (key != null) {
      mapSetPrimaryKeyValue(map, key);
    }
    var insertId = await transaction.insert(sqlTableName, map);
    var primaryKey = key ?? insertId;

    if (mapValue != null) {
      // Add the pk to the map in case it is needed by indexes.
      _fixRecordValueWithPk(primaryKey, mapValue);

      // Add the index value for each index for external tables
      for (var index in _indecies) {
        var keyValue = mapValue.getKeyValue(index.keyPath);
        if (keyValue != null) {
          await index.insertKey(insertId, keyValue);
        }
      }
    }

    return primaryKey;
  }

  @override
  Future<Object> add(Object value, [Object? key]) {
    value = toSqfliteValue(value);
    return _checkWritableStore(
      () => catchAsyncSqfliteError(() {
        checkKeyValueParam(
          keyPath: keyPath,
          key: key,
          value: value,
          autoIncrement: autoIncrement,
        );

        if (key == null && keyPath != null && value is Map) {
          key = mapValueAtKeyPath(value, keyPath);
        }

        return addImpl(value, key);
      }),
    );
  }

  /// Put a record
  Future<Object> putImpl(Object value, [Object? key]) async {
    var values = <String, Object?>{valueColumnName: encodeValue(value)};

    if (key == null && keyPath != null && value is Map) {
      key = mapValueAtKeyPath(value, keyPath);
    }
    if (key == null) {
      return addImpl(value);
    }
    var condition = KeyPathWhere.pkEquals(this, key);
    var count = await transaction.update(
      sqlTableName,
      values,
      where: condition.where,
      whereArgs: condition.whereArgs,
    );
    if (count == 0) {
      return addImpl(value, key);
    }

    // Add the index value for each index
    int? primaryId;
    for (var index in _indecies) {
      primaryId ??= await getPrimaryId(key);
      var keyValue = value is Map
          ? mapValueAtKeyPath(value, index.keyPath)
          : null;
      await index.updateKey(primaryId!, keyValue);
    }

    return key;
  }

  @override
  Future<Object> put(Object value, [Object? key]) {
    value = toSqfliteValue(value);
    return _checkWritableStore(
      () => catchAsyncSqfliteError(() {
        checkKeyValueParam(
          keyPath: keyPath,
          key: key,
          value: value,
          autoIncrement: autoIncrement,
        );

        if (key == null && keyPath != null && value is Map) {
          key = mapValueAtKeyPath(value, keyPath);
        }
        return putImpl(value, key);
      }),
    );
  }

  /// Only for keyPath not null and Map value
  Object? _getInlineKey(Object value) {
    var keyPath = this.keyPath;
    if (keyPath != null) {
      if (value is Map) {
        return value.getKeyValue(keyPath);
      }
    }
    return false;
  }

  /// A record with a keyPath added/read might not contain the pk in its value
  void _fixRecordValueWithPk(Object pk, Object value) {
    var keyPath = this.keyPath;
    if (keyPath != null) {
      if (value is Map) {
        if (value.getKeyValue(keyPath) == null) {
          value.setKeyValue(keyPath, pk);
        }
      }
    }
  }

  /// Convert a row to a record
  Object valueRowToRecord(Object pk, Object row) {
    var value = fromSqfliteValue(decodeValue(row)!);
    _fixRecordValueWithPk(pk, value);
    return value;
  }

  /// Get a record
  Future<Object?> getImpl(Object key) async {
    var row = await getFirstRow(
      key,
      columns: [...primaryKeyColumnNames, valueColumnName],
    );
    if (row == null) {
      return null;
    }
    return valueRowToRecord(rowGetPrimaryKeyValue(row), row[valueColumnName]!);
  }

  /// Returns null if not found
  Future<Map<String, Object?>?> getFirstRow(
    Object key, {
    required List<String> columns,
  }) async {
    // keyPath ??= this.keyPath;
    var condition = KeyPathWhere.pkEquals(this, key);
    var rows = await transaction.query(
      sqlTableName,
      columns: columns,
      where: condition.where,
      whereArgs: condition.whereArgs,
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first;
  }

  /// Returns the primary id (an int)
  Future<int?> getPrimaryId(Object key) async {
    var row = await getFirstRow(key, columns: [sqliteRowId]);
    return row?.values.first as int?;
  }

  /// Unused for now
  Future<List<int>> getPrimaryIds(KeyRange keyRange) async {
    var select = SqfliteSelectQuery(
      [sqliteRowId],
      sqlTableName,
      keyColumnNames,
      keyRange,
      null,
    );
    var rows = await select.execute(transaction);
    return rows.map((row) => row[sqliteRowId] as int).toList();
  }

  /// Return the primary key
  /// @deprecated once index is a table
  Future<Object?> getKeyImpl(Object key, [String? keyPath]) async {
    var row = await getFirstRow(key, columns: primaryKeyColumnNames);
    if (row == null) {
      return null;
    }
    return rowGetPrimaryKeyValue(row);
  }

  @override
  Future<Object?> getObject(Object key) {
    checkKeyParam(key);
    return checkStore(() {
      return getImpl(key);
    });
  }

  @override
  Future clear() {
    return _checkWritableStore(() async {
      await transaction.delete(sqlTableName);
    });
  }

  @override
  Future<void> delete(Object keyOrRange) {
    return _checkWritableStore(() async {
      await deleteImpl(keyOrRange);
    });
  }

  /// Delete a record
  Future<void> deleteImpl(Object keyOrRange) async {
    if (keyOrRange is KeyRange) {
      final query = SqfliteSelectQuery(
        [sqliteRowId],
        sqlTableName,
        primaryKeyColumnNames,
        keyOrRange,
        null,
      );
      query.buildParameters();
      await transaction.batch((batch) {
        for (var index in _indecies) {
          batch.delete(
            index.sqlIndexTableName,
            where:
                '$primaryIdColumnName IN (SELECT $sqliteRowId FROM $sqlTableName${query.sqlWhere != null ? ' WHERE ${query.sqlWhere}' : ''})',
            whereArgs: query.sqlWhereArgs,
          );
        }
        batch.delete(
          sqlTableName,
          where: query.sqlWhere,
          whereArgs: query.sqlWhereArgs,
        );
      });
    } else {
      var key = keyOrRange;
      // remove the index value
      var primaryId = await getPrimaryId(key);
      await transaction.batch((batch) {
        for (var index in _indecies) {
          batch.delete(
            index.sqlIndexTableName,
            where: '$primaryIdColumnName = ?',
            whereArgs: [primaryId],
          );
        }
        batch.delete(
          sqlTableName,
          where: '$sqliteRowId = ?',
          whereArgs: [primaryId],
        );
      });
    }
  }

  @override
  Index index(String name) {
    return _getIndex(name)!;
  }

  @override
  Index createIndex(String name, keyPath, {bool? unique, bool? multiEntry}) {
    // Be compatible with Chrome
    if (keyPath is List) {
      // // Native: InvalidAccessError: Failed to execute 'createIndex' on 'IDBObjectStore': The keyPath argument was an array and the multiEntry option is true.
      if (multiEntry ?? false) {
        throw DatabaseError(
          'The keyPath argument $keyPath cannot be an array if the multiEntry option is true',
        );
      }
    }
    var indexMeta = IdbIndexMeta(name, keyPath, unique, multiEntry);
    meta!.createIndex(database.meta, indexMeta);
    var index = IdbIndexSqflite(this, indexMeta);
    // let it for later
    return index;
  }

  @override
  void deleteIndex(String name) {
    meta!.deleteIndex(database.meta, name);
  }

  @override
  Stream<CursorWithValue> openCursor({
    key,
    KeyRange? range,
    String? direction,
    bool? autoAdvance,
  }) {
    var ctlr = IdbCursorWithValueControllerSqflite(
      this,
      direction ?? idbDirectionNext,
      autoAdvance ?? false,
    );

    checkOpenCursorArguments(key, range);

    // Future
    checkStore(() {
      return ctlr.execute(key, range);
    });
    return ctlr.stream;
  }

  @override
  Stream<Cursor> openKeyCursor({
    key,
    KeyRange? range,
    String? direction,
    bool? autoAdvance,
  }) {
    var ctlr = IdbKeyCursorControllerSqflite(
      this,
      direction ?? idbDirectionNext,
      autoAdvance ?? false,
    );

    checkOpenCursorArguments(key, range);

    // Future
    checkStore(() {
      return ctlr.execute(key, range);
    });
    return ctlr.stream;
  }

  @override
  Future<int> count([keyOrKeyRange]) {
    return checkStore(() {
      final query = SqfliteCountQuery(
        sqlTableName,
        primaryKeyColumnNames,
        keyOrKeyRange,
      );
      return query.count(transaction);
    });
  }

  @override
  Future<List<Object>> getAll([Object? query, int? count]) {
    return checkStore(() {
      var columns = [valueColumnName];
      var keyColumnNames = primaryKeyColumnNames;
      var selectQuery = SqfliteSelectQuery(
        columns,
        sqlTableName,
        keyColumnNames,
        query,
        idbDirectionNext,
        limit: count,
      );
      return selectQuery.execute(transaction).then((rs) {
        return rs
            .map((row) => fromSqfliteValue(decodeValue(row[valueColumnName])!))
            .toList(growable: false);
      });
    });
  }

  @override
  Future<List<Object>> getAllKeys([Object? query, int? count]) {
    return checkStore(() {
      var keyColumnNames = primaryKeyColumnNames;
      var columns = keyColumnNames;

      var selectQuery = SqfliteSelectQuery(
        columns,
        sqlTableName,
        keyColumnNames,
        query,
        idbDirectionNext,
        limit: count,
      );
      return selectQuery.execute(transaction).then((rs) {
        return rs
            .map((row) => rowGetPrimaryKeyValue(row))
            .toList(growable: false);
      });
    });
  }
}
