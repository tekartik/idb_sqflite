// ignore_for_file: implementation_imports, avoid_function_literals_in_foreach_calls
import 'dart:convert';
import 'dart:math';

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/src/common/common_database.dart';
import 'package:idb_shim/src/common/common_meta.dart';
import 'package:idb_shim/src/common/common_value.dart';
import 'package:idb_sqflite/src/core_imports.dart';
import 'package:idb_sqflite/src/sqflite_constant.dart';
import 'package:idb_sqflite/src/sqflite_factory.dart';
import 'package:idb_sqflite/src/sqflite_index.dart';
import 'package:idb_sqflite/src/sqflite_object_store.dart';
import 'package:idb_sqflite/src/sqflite_transaction.dart';
import 'package:idb_sqflite/src/sqflite_utils.dart';
import 'package:sqflite_common/sqlite_api.dart' as sqflite;

String sanitizeDbName(String name) => name;

class IdbVersionChangeEventSqflite extends IdbVersionChangeEventBase {
  IdbVersionChangeEventSqflite(
      IdbDatabaseSqflite database, int? oldVersion, this.newVersion) //
      : oldVersion = oldVersion ?? 0 {
    // handle = too to catch programatical errors
    if (this.oldVersion >= newVersion) {
      throw StateError('cannot downgrade from $oldVersion to $newVersion');
    }
    request = OpenDBRequest(database, database.versionChangeTransaction!);
  }

  @override
  final int oldVersion;
  @override
  final int newVersion;
  late Request request;

  @override
  Object get target => request;

  @override
  Database get database => transaction.database;

  /// added for convenience
  @override
  Transaction get transaction => request.transaction;

  @override
  String toString() {
    return '$oldVersion => $newVersion';
  }
}

class IdbDatabaseSqflite extends IdbDatabaseBase with DatabaseWithMetaMixin {
  IdbDatabaseSqflite(super.factory, String name) {
    meta.name = name;
  }

  IdbTransactionSqflite? versionChangeTransaction;

  sqflite.DatabaseFactory get sqfliteDatabaseFactory =>
      (super.factory as IdbFactorySqflite).sqfliteDatabaseFactory;

  @override
  IdbDatabaseMeta meta = IdbDatabaseMeta();

  sqflite.Database? sqlDb;

  Future applySchemaChanges(IdbOpenTransactionSqflite tx) async {
    final txnMeta = tx.meta
        as IdbVersionChangeTransactionMeta; // .versionChangeTransaction;

    Future createIndecies() async {
      for (var storeName in txnMeta.createdIndexes.keys) {
        var store = versionChangeTransaction!.objectStore(storeName)
            as IdbObjectStoreSqflite;
        var indexMetas = txnMeta.createdIndexes[storeName]!;
        for (var indexMeta in indexMetas) {
          var index = IdbIndexSqflite(store, indexMeta);
          await index.create();

          // if store was not created update the keys
          if (!txnMeta.createdStores
              .map((store) => store.name)
              .contains(storeName)) {
            var rows = await store.transaction.query(store.sqlTableName,
                columns: [
                  '$sqliteRowId as $primaryIdColumnName',
                  valueColumnName
                ]);
            if (rows.isNotEmpty) {
              await versionChangeTransaction!.batch((batch) {
                for (var row in rows) {
                  var value = decodeValue(row[valueColumnName]);
                  if (value is Map) {
                    var keyValue = mapValueAtKeyPath(value, index.keyPath);
                    index.insertKeyBatch(
                        batch, (row[primaryIdColumnName]) as int?, keyValue);
                  }
                }
              });
            }
          }
        }
      }
    }

    Future removeDeletedIndecies() async {
      for (var storeName in txnMeta.deletedIndexes.keys) {
        var store = versionChangeTransaction!.objectStore(storeName)
            as IdbObjectStoreSqflite;
        var indexMetas = txnMeta.deletedIndexes[storeName]!;
        for (var indexMeta in indexMetas) {
          var index = IdbIndexSqflite(store, indexMeta);
          await versionChangeTransaction!.batch(index.drop);
        }
      }
    }

    Future createObjectStores() async {
      for (var storeMeta in txnMeta.createdStores) {
        var store = IdbObjectStoreSqflite(versionChangeTransaction!, storeMeta);
        await store.create();
      }
    }

    Future updateObjectStores() async {
      for (var storeMeta in txnMeta.updatedStores) {
        var store = IdbObjectStoreSqflite(versionChangeTransaction!, storeMeta);
        await store.update();
      }
    }

    Future removeDeletedObjectStores() async {
      for (var storeMeta in txnMeta.deletedStores) {
        var store = IdbObjectStoreSqflite(versionChangeTransaction!, storeMeta);
        await store.deleteTable(versionChangeTransaction!);
        var sqlDelete = 'DELETE FROM $storesTable WHERE name = ?';
        var sqlArgs = [store.name];
        await versionChangeTransaction!.execute(sqlDelete, sqlArgs);
      }
    }

    // Delete store that have been deleted
    await removeDeletedObjectStores();
    await createObjectStores();
    await createIndecies();
    await removeDeletedIndecies();

    // Update meta for updated Store
    txnMeta.updatedStores
      ..removeAll(txnMeta.createdStores)
      ..removeAll(txnMeta.deletedStores);

    await updateObjectStores();

    // Remove pending meta change in case it is called again
    // Simply create another meta
    // txnMeta.clearChanges(); // TODO implement in idb_shim
    txnMeta.deletedIndexes.clear();
    txnMeta.createdIndexes.clear();
    txnMeta.createdStores.clear();
    txnMeta.deletedStores.clear();
    txnMeta.updatedStores.clear();
  }

  Future _upgrade(IdbTransactionSqflite tx, int? oldVersion, int newVersion,
      FutureOr<void> Function(VersionChangeEvent event) onUpgradeNeeded) async {
    versionChangeTransaction = tx;
    try {
      var event = IdbVersionChangeEventSqflite(this, oldVersion, newVersion);

      await onUpgradeNeeded(event);

      await applySchemaChanges(tx as IdbOpenTransactionSqflite);
    } finally {
      // nullify when done
      versionChangeTransaction = null;
    }
  }

  Future open(int? newVersion, OnUpgradeNeededFunction? onUpgradeNeeded) async {
    int? oldVersion;

    /// Open the sqflite database
    /// When done oldVersion is initialized
    Future<sqflite.Database> openSqlDb(String name) {
      /// Init the database
      /// Set oldVersion to 0
      Future initDatabase(sqflite.Database db) async {
        await db.execute('DROP TABLE IF EXISTS $versionTable'); //

        await db.execute(
            'CREATE TABLE $versionTable ($versionField INT, $signatureField TEXT)');
        await db.insert(versionTable, <String, Object?>{
          versionField: 0,
          signatureField: internalSignature
        });
        await db.execute('DROP TABLE IF EXISTS $storesTable');
        await db.execute('CREATE TABLE $storesTable ' //
            '($nameField TEXT UNIQUE, $metaField TEXT)');
        oldVersion = 0;
      }

      var path = sanitizeDbName(name);
      return sqfliteDatabaseFactory.openDatabase(path,
          options: sqflite.OpenDatabaseOptions(
              version: internalVersion,
              onConfigure: (db) async {
                await db.execute('PRAGMA foreign_keys = ON');
              },
              onCreate: (db, _) async {
                await initDatabase(db);
              },
              onDowngrade: sqflite.onDatabaseDowngradeDelete,
              onOpen: (db) async {
                if (oldVersion == null) {
                  try {
                    var list = await db.query(versionTable,
                        columns: [versionField, signatureField]);
                    if (list.length != 1) {
                      throw '1 record expected in $versionTable';
                    }
                    var row = list.first;
                    var signature = row[signatureField]?.toString();
                    if (signature != internalSignature) {
                      throw 'unexpected signature $signature';
                    }
                    oldVersion = row[versionField] as int?;
                    if (oldVersion == null) {
                      throw 'null version';
                    }
                  } catch (e) {
                    if (isDebug) {
                      // ignore: avoid_print
                      print(e);
                    }
                    await initDatabase(db);
                  }
                }
              }));
    }

    // Set right away needed from transaction
    sqlDb = await openSqlDb(name);

    Future checkVersion(IdbTransactionSqflite transaction) async {
      var upgrading = false;
      // devPrint('_checkVersion $oldVersion $newVersion');

      // Special first open case if new version is not specified
      newVersion ??= max(oldVersion ?? 0, 1);

      // Wrap in init block so that last one win

      // Prevent upgrading when opening twice the database
      // oldVersion is only null if the database was already opened
      oldVersion ??= newVersion;

      // Set the version right away it used
      meta.version = newVersion;

      //print('$oldVersion vs $newVersion');
      if (oldVersion != newVersion) {
        if (oldVersion! > newVersion!) {
          // cannot downgrade
          throw StateError('cannot downgrade from $oldVersion to $newVersion');
        } else {
          upgrading = true;

          Future updateVersion() async {
            // return initBlock(() {
            await transaction
                    .update(versionTable, {versionField: newVersion}) //
                ;
          }

          //return initBlock(() {
          await _loadStores(transaction);
          if (onUpgradeNeeded != null) {
            await meta.onUpgradeNeeded(() async {
              var oldMeta = transaction.meta;
              try {
                transaction.meta = meta.versionChangeTransaction;
                await _upgrade(
                    transaction, oldVersion, newVersion!, onUpgradeNeeded);
              } finally {
                transaction.meta = oldMeta;
              }
            });
          }
          await updateVersion();
        }
      }

      if (!upgrading) {
        await _loadStores(transaction);
      }
    }

    // Special transaction without store
    var txnMeta = meta.transaction(null, idbModeReadWrite);
    var transaction = IdbOpenTransactionSqflite(this, txnMeta);
    try {
      await transaction.run(() async {
        await checkVersion(transaction);
      });
      await transaction.completed;
    } catch (e) {
      // On error close
      // devPrint('open exception $e');
      close();
      rethrow;
    }
  }

  @override
  ObjectStore createObjectStore(String name,
      {Object? keyPath, bool? autoIncrement = false}) {
    var storeMeta = IdbObjectStoreMeta(name, keyPath, autoIncrement);
    meta.createObjectStore(storeMeta);

    var store = IdbObjectStoreSqflite(versionChangeTransaction!, storeMeta);
    return store;
  }

  /// Load stores meta data
  Future _loadStores(IdbTransactionSqflite transaction) async {
    var list =
        await transaction.query(storesTable, columns: [nameField, metaField]);
    list.forEach((row) {
      var map =
          (jsonDecode(row['meta'] as String) as Map).cast<String, Object?>();
      var storeMeta = IdbObjectStoreMeta.fromMap(map);
      meta.putObjectStore(storeMeta);
    });
  }

  @override
  Transaction transaction(storeNameOrStoreNames, String mode) {
    var txnMeta = meta.transaction(storeNameOrStoreNames, mode);

    return IdbTransactionSqflite(this, txnMeta);
  }

  @override
  Transaction transactionList(List<String> stores, String mode) {
    var txnMeta = meta.transaction(stores, mode);
    return IdbTransactionSqflite(this, txnMeta);
  }

  @override
  void close() {
    sqlDb?.close();
    sqlDb = null;
    onVersionChangeCtlr?.close();
  }

  // Only created when we asked for it
  // singleton
  StreamController<VersionChangeEvent>? onVersionChangeCtlr;

  @override
  Stream<VersionChangeEvent> get onVersionChange {
    // only fired when a new call is made!
    if (onVersionChangeCtlr != null) {
      throw UnsupportedError('onVersionChange should be called only once');
    }
    // sync needed in testing to make sure we receive the onCloseEvent before the
    // new database is actually open (test: websql database one keep open then one)
    onVersionChangeCtlr = StreamController(sync: true);
    return onVersionChangeCtlr!.stream;
  }
}
