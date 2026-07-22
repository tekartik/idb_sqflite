@TestOn('vm')
library;

import 'package:idb_sqflite/sdb_sqflite.dart';
import 'package:idb_sqflite/src/idb_import.dart';
import 'package:idb_sqflite/src/sqflite_factory.dart' show IdbFactorySqflite;
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

//import '../idb_test_common.dart';

void main() {
  databaseFactory = databaseFactoryFfi;
  var factory = idbFactorySqflite;

  group('sandbox_sqflite_ffi', () {
    var factory =
        idbFactorySqflite.sandbox(path: 'sandbox') as IdbFactorySandbox;

    test('delegatePath', () async {
      expect(
        factory.delegatePath('test.db'),
        endsWith(join('sandbox', 'test.db')),
      );
      expect(factory.delegatePath(inMemoryDatabasePath), inMemoryDatabasePath);
    });

    test('inMemoryDatabasesPath', () async {
      expect(
        await factory.getDatabaseFullPath(inMemoryDatabasePath),
        inMemoryDatabasePath,
      );
    });
    test('full path', () async {
      expect(
        await factory.getDatabaseFullPath('test.db'),
        endsWith(join('sandbox', 'test.db')),
      );
    });
  });
  group('sdb_factory_io', () {
    test('getDatabaseFullPath()', () async {
      expect(
        await factory.getDatabaseFullPath(inMemoryDatabasePath),
        inMemoryDatabasePath,
      );
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
  test('isImmutableDatabaseName()', () {
    var base = factory as IdbFactoryBase;
    expect(base.isImmutableDatabaseName('test'), isFalse);
    expect(base.isImmutableDatabaseName(':memory:'), isTrue);
    expect(base.isImmutableDatabaseName(inMemoryDatabasePath), isTrue);
  });
  group('supportsDatabaseNames', () {
    test('dbName', () async {
      var idbFactorySqflite = factory as IdbFactorySqflite;
      // ignore: deprecated_member_use
      expect(idbFactorySqflite.supportsDatabaseNames, isFalse);
      var sandboxed = factory.sandbox(path: 'sub');
      // ignore: deprecated_member_use
      expect(sandboxed.supportsDatabaseNames, isFalse);
    });
  });
}
