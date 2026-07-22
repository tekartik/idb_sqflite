@TestOn('vm')
library;

import 'package:idb_sqflite/sdb_sqflite.dart';
import 'package:idb_sqflite_common_test/sdb_sqflite_test.dart';
import 'package:idb_sqflite_common_test/src/idb_sqflite_mixin.dart'
    show SdbFactorySandbox;
import 'package:idb_test/idb_test_common.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

Future main() async {
  // Set sqflite ffi support in test
  ffi.sqfliteFfiInit();

  var rawFactory = sdbFactoryFromSqflite(ffi.databaseFactoryFfi);
  var factory = rawFactory.sandbox(path: 'sandbox') as SdbFactorySandbox;

  group('sdb_sandbox_sqflite_ffi', () {
    defineSdbSqfliteTests(factory);
  });
}
