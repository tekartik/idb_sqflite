import 'dart:async';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:test/test.dart';
import 'package:idb_test/test_runner.dart';
import 'package:idb_sqflite_common_test/idb_sqflite_test.dart'
    as idb_sqflite_test;
import 'package:idb_sqflite_common_test/sqflite_transaction_wrapper_test.dart'
    as transaction_wrapper;
import 'idb_sqflite_test_common.dart';

Future main() async {
  // Set sqflite ffi support in test
  sqfliteFfiInit();

  var factory = databaseFactoryFfi;
  // factory.setLogLevel(sqfliteLogLevelVerbose);
  group('sqflite_ffi', () {
    var idbContext = TestContextSqfliteFfi();
    defineAllTests(idbContext);
    idb_sqflite_test.defineTests(idbContext.factory);
    transaction_wrapper.defineTests(factory);
  });
}
