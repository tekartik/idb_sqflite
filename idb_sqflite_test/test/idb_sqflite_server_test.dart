import 'dart:async';

import 'package:sqflite_test/sqflite_test.dart';

import 'package:test/test.dart';
import 'package:idb_test/test_runner.dart';
import 'package:idb_sqflite_common_test/idb_sqflite_test.dart'
    as idb_sqflite_test;
import 'package:idb_sqflite_common_test/sqflite_transaction_wrapper_test.dart'
    as transaction_wrapper;
import 'idb_sqflite_server_test_common.dart';

Future main() async {
  var sqfliteTestContext = await SqfliteServerTestContext.connect();
  if (sqfliteTestContext != null) {
    var factory = sqfliteTestContext.databaseFactory;
    group('sqflite_server', () {
      var idbContext = TestContextSqfliteServer(factory);
      defineAllTests(idbContext);
      idb_sqflite_test.defineTests(idbContext.factory);
      transaction_wrapper.defineTests(factory);
    });
  } else {
    test('no server', () {});
  }
}
