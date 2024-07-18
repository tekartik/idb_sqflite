@TestOn('vm')
library;

import 'package:idb_sqflite/sdb_sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:test/test.dart';

Future main() async {
  // Set sqflite ffi support in test
  ffi.sqfliteFfiInit();

  var factory = sdbFactoryFromSqflite(ffi.databaseFactoryFfi);
  // await factory.setLogLevel(sqfliteLogLevelVerbose);
  group('sdb_sqflite_ffi', () {
    test('inMemory', () async {
      var testStore = SdbStoreRef<int, SdbModel>('test');
      var db = await factory.openDatabase(inMemoryDatabasePath, version: 1,
          onVersionChange: (event) {
        var oldVersion = event.oldVersion;
        if (oldVersion < 1) {
          event.db.createStore(testStore);
        }
      });

      var key = await testStore.add(db, {'test': 1});
      expect((await testStore.record(key).get(db))!.value, {'test': 1});
    });
  });
}
