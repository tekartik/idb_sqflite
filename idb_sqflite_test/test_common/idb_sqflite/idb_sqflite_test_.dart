import 'package:idb_shim/idb_client.dart';
import 'package:idb_sqflite/idb_sqflite.dart';
import 'package:idb_sqflite/src/sqflite_database.dart';

import '../idb_sqflite_test_common.dart';

void defineTests(IdbFactory factory) {
  group('impl', () {
    test('open_transaction_open', () async {
      Database db;
      try {
        var dbName = 'delete_database.db';
        await factory.deleteDatabase(dbName);

        void _initializeDatabase(VersionChangeEvent e) {
          Database db = e.database;
          db.createObjectStore('name', keyPath: 'keyPath', autoIncrement: true);
        }

        db = await factory.open(dbName,
            version: 1, onUpgradeNeeded: _initializeDatabase);
        // Create a transaction and close right away
        db.transaction('name', idbModeReadOnly);

        // await transaction.completed;
        db.close();
        // Make sure we can re-open the db
        db = await factory.open(dbName);
      } finally {
        db?.close();
      }
      // await factory.deleteDatabase(dbName);

      //await factory.deleteDatabase(dbName);
    });

    group('multi_entry', () {
      test('extra_table', () async {
        void _initializeDatabase(VersionChangeEvent e) {
          Database db = e.database;
          ObjectStore objectStore =
              db.createObjectStore(testStoreName, autoIncrement: true);
          objectStore.createIndex(testNameIndex, testNameField,
              multiEntry: true);
        }

        var name = 'impl_multi_entry';
        await factory.deleteDatabase(name);
        var db = await factory.open(name,
            version: 1, onUpgradeNeeded: _initializeDatabase);

        var sqlDb = (db as IdbDatabaseSqflite).sqlDb;
        var list = await sqlDb.query('sqlite_master');

        var names = list.map((item) => item['name']);
        // print(names.join(','));
        expect(
            names,
            containsAll([
              '__version',
              '__stores',
              's__test_store',
              'test_store__name_index',
              'test_store__name_index__j',
              'test_store__name_index__k',
              'test_store__name_index__pid'
            ]));
        db.close();

        // Make sure the table get deleted
        db = await factory.open(name, version: 2, onUpgradeNeeded: (e) {
          var db = e.database;
          db.deleteObjectStore(testStoreName);
        });
        sqlDb = (db as IdbDatabaseSqflite).sqlDb;
        list = await sqlDb.query('sqlite_master');

        names = list.map((item) => item['name']);
        // print(names.join(','));
        expect(names, isNot(contains('s__test_store')));
        expect(names, isNot(contains('test_store__name_index')));
        expect(names, isNot(contains('test_store__name_index__j')));
        expect(names, isNot(contains('test_store__name_index__k')));
        expect(names, isNot(contains('test_store__name_index__pid')));

        db.close();
      });
    });

    group('index', () {
      test('content', () async {
        void _initializeDatabase(VersionChangeEvent e) {
          Database db = e.database;
          ObjectStore objectStore =
              db.createObjectStore(testStoreName, autoIncrement: true);
          objectStore.createIndex(testNameIndex, testNameField);
        }

        var name = 'impl_multi_entry';
        await factory.deleteDatabase(name);
        var db = await factory.open(name,
            version: 1, onUpgradeNeeded: _initializeDatabase);

        try {
          var txn = db.transaction(testStoreName, idbModeReadWrite);
          var store = txn.objectStore(testStoreName);
          var pk = await store.put({testNameField: 1234});
          var sqlDb = (db as IdbDatabaseSqflite).sqlDb;
          var list = await sqlDb.query('s__test_store');
          print(list);
          expect(list, [
            {'pk': 1, 'v': '{"name":1234}'}
          ]);
          list = await sqlDb.query('test_store__name_index');
          expect(list, [
            {'k': 1234, 'pid': 1}
          ]);
          await txn.completed;
          txn = db.transaction(testStoreName, idbModeReadWrite);
          store = txn.objectStore(testStoreName);
          await store.delete(pk);
          list = await sqlDb.query('test_store__name_index');
          expect(list, []);
        } finally {
          db.close();
        }
      });
    });
  });
}
