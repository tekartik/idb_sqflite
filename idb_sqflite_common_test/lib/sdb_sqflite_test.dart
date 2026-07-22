// ignore: implementation_imports
import 'dart:io';

import 'package:idb_shim/sdb.dart';
//import 'package:idb_sqflite/src/sqflite_database.dart';
import 'package:idb_test/idb_test_common.dart';
import 'package:idb_test/sdb_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common/sqflite.dart' show inMemoryDatabasePath;

/// Define the tests
void defineSdbSqfliteTests(SdbFactory factory) {
  group('sdb_sqflite_test', () {
    test('in memory', () async {
      var db = await factory.openDatabase(
        inMemoryDatabasePath,
        options: testStoreOpenOptions,
      );
      await db.close();
    });
    test('missing dir and absolute', () async {
      var dbName = join('missing_dir', 'sub', 'missing_dir.db');
      var path = await factory.getDatabaseFullPath(dbName);

      if (!kSdbDartIsWeb) {
        try {
          await Directory(dirname(dirname(path))).delete(recursive: true);
        } catch (_) {}
      }
      var db = await factory.openDatabase(path, options: testStoreOpenOptions);
      await db.close();
    });
  });
  //
}
