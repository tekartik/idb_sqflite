import 'package:idb_sqflite/src/sqflite_factory.dart';
import 'package:sqflite/sqlite_api.dart' as sqflite;
import 'package:sqflite/sqflite.dart';

import '../test_common/idb_shim/idb_test_common.dart';

export '../test_common/idb_shim/idb_test_common.dart';

class TestContextSqfliteServer extends TestContext {
  final sqflite.DatabaseFactory sqfliteDatabaseFactory;

  TestContextSqfliteServer(this.sqfliteDatabaseFactory) {
    factory = IdbFactorySqflite(sqfliteDatabaseFactory);
  }

  @override
  bool get isInMemory => false;
}

class TestContextSqfliteFfi extends TestContext {
  TestContextSqfliteFfi() {
    factory = IdbFactorySqflite(databaseFactory);
  }

  @override
  bool get isInMemory => false;
}
