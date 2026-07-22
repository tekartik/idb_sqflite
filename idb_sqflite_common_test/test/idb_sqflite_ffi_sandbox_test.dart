@TestOn('vm')
library;

import 'package:idb_sqflite_common_test/idb_sqflite_test.dart'
    as idb_sqflite_test;
import 'package:idb_test/idb_test_common.dart';
import 'package:idb_test/test_runner.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import 'idb_sqflite_test_common.dart';

Future main() async {
  // Set sqflite ffi support in test
  ffi.sqfliteFfiInit();

  var idbContext = TestContextSqfliteFfi();
  var factory = idbContext.factory = idbContext.factory.sandbox(
    path: 'sandbox',
  );

  group('sqflite_ffi', () {
    defineAllTests(idbContext);
    idb_sqflite_test.defineTests(factory);

    test('full path', () async {
      expect(
        await factory.getDatabaseFullPath('test.db'),
        endsWith(join('sandbox', 'test.db')),
      );
    });
  });
}
