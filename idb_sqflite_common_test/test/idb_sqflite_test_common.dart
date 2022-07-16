import 'package:idb_sqflite/src/sqflite_factory.dart';
import 'package:idb_test/idb_test_common.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
export 'package:sqflite_common/sqflite_dev.dart';
export 'package:sqflite_common/sqlite_api.dart' hide Database;

class TestContextSqfliteFfi extends TestContext {
  TestContextSqfliteFfi() {
    factory = IdbFactorySqflite(databaseFactoryFfi);
  }

  @override
  bool get isInMemory => false;
}
