@TestOn('vm')
library;

import 'dart:io';

import 'package:idb_sqflite/sdb_sqflite.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

//import '../idb_test_common.dart';

void main() {
  group('sdb_factory_io', () {
    late SdbFactory factory;
    late String databasesPath;
    setUp(() async {
      // Use sqflite_common_ffi on Dart VM
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;

      // Set from the default sqflite factory
      factory = sdbFactorySqflite;
      databasesPath = dirname(await factory.getDatabaseFullPath('test.db'));
    });
    test('open non existing folder', () async {
      var nonExistingFolderDbPath = normalize(
        absolute(join(databasesPath, 'non_existing_folder', 'test.db')),
      );
      try {
        await Directory(
          dirname(nonExistingFolderDbPath),
        ).delete(recursive: true);
      } catch (e) {
        // ignore
      }
      var db = await factory.openDatabase(
        nonExistingFolderDbPath,
        options: SdbOpenDatabaseOptions(
          version: 1,
          onVersionChange: (event) {
            var oldVersion = event.oldVersion;
            if (oldVersion < 1) {
              event.db.createStore(SdbStoreRef<int, SdbModel>('test'));
            }
          },
        ),
      );

      await db.close();
    });
    test('open invalid data', () async {
      var dbPath = join(databasesPath, 'invalid_data.db');
      await File(dbPath).writeAsString('invalid data');
      try {
        await factory.openDatabase(
          dbPath,
          options: SdbOpenDatabaseOptions(
            version: 1,
            onVersionChange: (event) {
              var oldVersion = event.oldVersion;
              if (oldVersion < 1) {
                event.db.createStore(SdbStoreRef<int, SdbModel>('test'));
              }
            },
          ),
        );
        fail('should fail');
      } catch (e) {
        expect(e, isNot(isA<TestFailure>()));
        // ignore: avoid_print
        print('failed to open $dbPath: $e');
      }
    });
  });
}
