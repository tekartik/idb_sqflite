import 'package:idb_sqflite/src/sqflite_factory.dart';
import 'package:idb_test/idb_test_common.dart';
import 'package:sqflite/sqlite_api.dart' as sqflite;

export 'package:sqflite_common/sqflite_dev.dart';
export 'package:sqflite_common/sqlite_api.dart';

class TestContextSqfliteServer extends TestContext {
  final sqflite.DatabaseFactory sqfliteDatabaseFactory;

  TestContextSqfliteServer(this.sqfliteDatabaseFactory) {
    factory = IdbFactorySqflite(sqfliteDatabaseFactory);
  }

  @override
  bool get isInMemory => false;
}
