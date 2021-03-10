import 'dart:async';

import 'package:idb_shim/idb_client_logger.dart';
import 'package:idb_test/test_runner.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

import 'idb_sqflite_test_common.dart';

Future main() async {
  // Set sqflite ffi support in test
  sqfliteFfiInit();

  // await factory.setLogLevel(sqfliteLogLevelVerbose);
  group('sqflite_ffi', () {
    var idbContext = TestContextSqfliteFfi();
    var factory = getIdbFactoryLogger(idbContext.factory!);
    idbContext.factory = factory;

    defineAllTests(idbContext);
  });
}
