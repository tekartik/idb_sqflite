import 'package:idb_sqflite/idb_client_sqflite.dart';
import 'package:idb_sqflite/idb_sqflite.dart';

import 'idb_shim/idb_test_common.dart';

export 'idb_shim/idb_test_common.dart';

class TestContextSqflite extends TestContext {
  TestContextSqflite() {
    factory = idbFactorySqflite;
  }

  @override
  bool get isInMemory => false;
}

final testContextSqflite = TestContextSqflite();
