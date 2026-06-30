@TestOn('vm')
library;

import 'package:idb_sqflite/sdb_sqflite.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

//import '../idb_test_common.dart';

void main() {
  databaseFactory = databaseFactoryFfi;
  var factory = sdbFactorySqflite;

  group('sdb_factory_io', () {
    test('getDatabaseFullPath()', () async {
      var databasesPath = await databaseFactory.getDatabasesPath();
      expect(
        canonicalize(await factory.getDatabaseFullPath('test.db')),
        canonicalize(join(databasesPath, 'test.db')),
      );

      expect(
        canonicalize(
          await factory.sandbox(path: 'sub').getDatabaseFullPath('test.db'),
        ),
        canonicalize(join(databasesPath, 'sub', 'test.db')),
      );
    });
    test('sqflite database path', () async {
      var databasesPath = await databaseFactory.getDatabasesPath();
      try {
        var here = normalize(
          absolute(join('.dart_tool', 'idb_sqflite_test', 'db_path')),
        );
        await databaseFactory.setDatabasesPath(here);

        expect(
          await factory.getDatabaseFullPath('test.db'),
          join(here, 'test.db'),
        );
      } finally {
        await databaseFactory.setDatabasesPath(databasesPath);
      }
    });
  });
  test('sandbox database path', () async {
    var here = normalize(
      absolute(join('.dart_tool', 'idb_sqflite_test', 'db_path')),
    );
    var sanboxed = factory.sandbox(path: here);

    expect(
      await sanboxed.getDatabaseFullPath('test.db'),
      join(here, 'test.db'),
    );
  });
}
