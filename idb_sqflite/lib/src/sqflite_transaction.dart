// ignore_for_file: implementation_imports
import 'dart:async';

import 'package:idb_shim/idb.dart';
import 'package:idb_sqflite/src/sqflite_database.dart';
import 'package:idb_sqflite/src/sqflite_object_store.dart';
import 'package:idb_sqflite/src/sqflite_transaction_wrapper.dart';
import 'package:sqflite_common/sqlite_api.dart' as sqflite;
import 'idb_import.dart';

/// Internal
bool debugTransactionSqflite = false; // devWarning(true);

/// Open transaction
class IdbOpenTransactionSqflite extends IdbTransactionSqflite {
  /// Open transaction
  IdbOpenTransactionSqflite(super.database, IdbTransactionMeta super.meta);
}

/// Transaction
class IdbTransactionSqflite extends IdbTransactionBase
    with TransactionWithMetaMixin {
  /// Transaction
  IdbTransactionSqflite(IdbDatabaseSqflite database, this.meta)
    : super(database) {
    _txn = SqfliteTransactionWrapper(database.sqlDb);

    // Mark complete as soon as possible
    // _checkCompletion();
  }

  // Change during onVersionChanged
  @override
  IdbTransactionMeta? meta;
  late SqfliteTransactionWrapper _txn;
  // Use for aborted

  /// Database
  IdbDatabaseSqflite get idbDatabaseSqflite => database as IdbDatabaseSqflite;

  @override
  ObjectStore objectStore(String name) {
    meta!.checkObjectStore(name);
    return IdbObjectStoreSqflite(
      this,
      idbDatabaseSqflite.meta.getObjectStore(name),
    );
  }

  @override
  String toString() {
    return meta.toString();
  }

  /// Make sure the transaction don't exit
  Future run(Future Function() action) => _txn.run((_) => action());

  @override
  Future<Database> get completed => _txn.completed.then((_) => database);

  /// Execute
  Future execute(String sql, [List<dynamic>? arguments]) =>
      _txn.run((txn) => txn.execute(sql, arguments as List<Object>?));

  /// Insert
  Future<int> insert(String table, Map<String, Object?> values) =>
      _txn.run((txn) => txn.insert(table, values));

  /// Query
  Future<List<Map<String, Object?>>> query(
    String table, {
    List<String>? columns,
    String? where,
    List<Object>? whereArgs,
    String? orderBy,
    int? limit,
  }) => _txn.run(
    (txn) => txn.query(
      table,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      limit: limit,
      orderBy: orderBy,
    ),
  );

  /// Update
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object>? whereArgs,
  }) => _txn.run(
    (txn) => txn.update(table, values, where: where, whereArgs: whereArgs),
  );

  /// Raw query
  Future<List<Map<String, Object?>>> rawQuery(
    String sqlSelect,
    List<Object>? args,
  ) => _txn.run((txn) => txn.rawQuery(sqlSelect, args));

  /// Delete
  Future<int> delete(String table, {String? where, List<Object>? whereArgs}) =>
      _txn.run((txn) => txn.delete(table, where: where, whereArgs: whereArgs));

  /// Batch
  Future<List<dynamic>> batch(void Function(sqflite.Batch batch) prepare) =>
      _txn.run((txn) {
        var batch = txn.batch();
        prepare(batch);
        return batch.commit();
      });

  @override
  void abort() {
    _txn.abort();
  }

  /// End exception
  Exception? get endException => _txn.completedException;
}
