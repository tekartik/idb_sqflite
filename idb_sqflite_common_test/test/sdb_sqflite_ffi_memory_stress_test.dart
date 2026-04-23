@TestOn('vm')
library;

import 'package:idb_sqflite/sdb_sqflite.dart';
import 'package:idb_test/idb_test_common.dart';
import 'package:idb_test/src/stress_notes_db_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

Future<void> main() async {
  // Set sqflite ffi support in test
  ffi.sqfliteFfiInit();
  var factory = sdbFactoryFromSqflite(ffi.databaseFactoryFfi);

  sdbStressAddListNotesGroup(
    factory,

    dbName: inMemoryDatabasePath,
    addedCount: [2000, 5000, 10000],
  );
}
