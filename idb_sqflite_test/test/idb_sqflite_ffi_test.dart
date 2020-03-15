import 'dart:async';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../test_common/idb_shim/test_runner.dart';
import '../test_common/idb_sqflite/idb_sqflite_test_.dart' as sqflite_test;
import '../test_common/idb_sqflite/sqflite_transaction_wrapper_test_.dart'
    as transaction_wrapper;
import 'idb_sqflite_server_test_common.dart';

Future main() async {
  // Set sqflite ffi support in test
  sqfliteFfiInit();

  var factory = databaseFactoryFfi;
  group('sqflite_ffi', () {
    var idbContext = TestContextSqfliteFfi();
    defineTests(idbContext);
    sqflite_test.defineTests(idbContext.factory);
  });
  group('transaction_wrapper', () {
    transaction_wrapper.defineTests(factory);
  });
}
