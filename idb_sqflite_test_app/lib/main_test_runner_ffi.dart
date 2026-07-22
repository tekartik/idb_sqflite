import 'package:flutter/widgets.dart';
import 'package:idb_shim/idb_sdb.dart';
import 'package:idb_sqflite/idb_sqflite.dart';
import 'package:idb_sqflite_common_test/idb_sqflite_test.dart'
    as idb_sqflite_test;
import 'package:idb_sqflite_common_test/sdb_sqflite_test.dart'
    as sdb_sqflite_test;
import 'package:idb_test/idb_test_common.dart';
import 'package:idb_test/test_runner.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_ffi/sqflite_ffi.dart' as ffi;

/// Test context running the idb_sqflite test suite against the platform
/// sqflite database factory (ffi on Windows/Linux, the plugin elsewhere).
class TestRunnerContext extends TestContext {
  final sqflite.DatabaseFactory sqfliteDatabaseFactory;

  TestRunnerContext(this.sqfliteDatabaseFactory)
    : super(factory: getIdbFactorySqflite(ffi.sqfliteDatabaseFactoryFfi));

  @override
  bool get isInMemory => false;
}

/// Entry point to run the idb_sqflite test suite in a Flutter app (no UI,
/// console output only).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ffi.sqfliteFfiInit();
  var databaseFactory = ffi.sqfliteDatabaseFactoryFfi;

  var testContext = TestRunnerContext(databaseFactory);
  var supportDir = await getApplicationSupportDirectory();
  testContext.factory = testContext.factory.sandbox(
    path: join(supportDir.path, 'databases'),
  );
  group('idb_sqflite_ffi', () {
    defineAllTests(testContext);
    idb_sqflite_test.defineTests(testContext.factory);
    sdb_sqflite_test.defineSdbSqfliteTests(
      sdbFactoryFromIdb(testContext.factory),
    );
    //transaction_wrapper.defineTests(testContext.sqfliteDatabaseFactory);
  });
}
