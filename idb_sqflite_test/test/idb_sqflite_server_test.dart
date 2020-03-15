import 'dart:async';

import 'package:sqflite_test/sqflite_test.dart';

import '../test_common/idb_shim/test_runner.dart';
import '../test_common/idb_sqflite/idb_sqflite_test_.dart' as sqflite_test;
import '../test_common/idb_sqflite/sqflite_transaction_wrapper_test_.dart'
    as transaction_wrapper;
import 'idb_sqflite_server_test_common.dart';

Future main() async {
  var sqfliteTestContext = await SqfliteServerTestContext.connect();
  if (sqfliteTestContext != null) {
    var factory = sqfliteTestContext.databaseFactory;
    group('sqflite_server', () {
      var idbContext = TestContextSqfliteServer(factory);
      defineTests(idbContext);
      sqflite_test.defineTests(idbContext.factory);
    });
    group('transaction_wrapper', () {
      transaction_wrapper.defineTests(factory);
    });
  }
}
