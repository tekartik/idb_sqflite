@TestOn('vm')
library;

import 'package:idb_sqflite/idb_client_sqflite.dart';
import 'package:idb_sqflite_common_test/idb_sqflite_test.dart'
    as idb_sqflite_test;
import 'package:idb_sqflite_common_test/sqflite_transaction_wrapper_test.dart'
    as transaction_wrapper;
import 'package:idb_test/idb_test_common.dart';
import 'package:idb_test/test_runner.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import 'idb_sqflite_test_common.dart';

Future main() async {
  // Set sqflite ffi support in test
  ffi.sqfliteFfiInit();

  var factory = ffi.databaseFactoryFfi;
  // await factory.setLogLevel(sqfliteLogLevelVerbose);
  group('sqflite_ffi', () {
    var idbContext = TestContextSqfliteFfi();
    defineAllTests(idbContext);
    idb_sqflite_test.defineTests(idbContext.factory);
    transaction_wrapper.defineTests(factory);
  });

  group('big insert/query', () {
    var sqfliteDatabaseFactory = ffi.databaseFactoryFfiNoIsolate;
    // sqfliteDatabaseFactory.debugSetLogLevel(sqfliteLogLevelVerbose);
    var factory = getIdbFactorySqflite(
      sqfliteDatabaseFactory,
    ); // idbFactoryNative;

    var objectStoreName = 'test';

    Future<void> testInsert(Database db, {int count = 100000}) async {
      var txn = db.transaction(objectStoreName, idbModeReadWrite);
      var os = txn.objectStore(objectStoreName);
      for (var i = 0; i < count; i++) {
        await os.add({'intValue': i + 1});
      }
    }

    Future<void> testQuery(Database db, {int count = 100000}) async {
      var txn = db.transaction(objectStoreName, idbModeReadOnly);
      var os = txn.objectStore(objectStoreName);
      var cursor = os.openCursor(autoAdvance: true);
      var result = await cursor.toList();
      expect(result.length, count);
      // print('result count ${result.length}');
    }

    Future<void> testAll(IdbFactory factory, {int count = 100000}) async {
      // var sw = Stopwatch()..start();
      var db = await factory.open(
        inMemoryDatabasePath,
        version: 1,
        onUpgradeNeeded: (vce) {
          var db = vce.database;
          db.createObjectStore(objectStoreName, autoIncrement: true);
        },
      );
      await testInsert(db, count: count);
      await testQuery(db, count: count);
      db.close();
      // 10000 0.22
      // 100000 0.90 (i9 12900K)
      // devPrint('elapsed: ${sw.elapsed}');
    }

    test('100000 query', () async {
      await testAll(factory, count: 100000);
    });

    // Exp, tried with 1 000 000 here!
    test('some queries', () async {
      await testAll(factory, count: 10);
    });
  });
}
