import 'package:flutter_test/flutter_test.dart';
import 'package:idb_shim/idb_shim.dart';
import 'package:idb_sqflite_test_app/main_test_runner.dart' as runner;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The runner context used to ignore its factory (always the plugin, which
  // has no Linux/Windows implementation).
  test('the runner context opens with the factory it is given', () async {
    ffi.sqfliteFfiInit();
    // ffi, as main() passes it on Linux and Windows.
    var context = runner.TestRunnerContext(ffi.databaseFactoryFfi);
    var db = await context.factory.open(
      ffi.inMemoryDatabasePath,
      version: 1,
      onUpgradeNeeded: (event) {
        event.database.createObjectStore('test');
      },
    );
    try {
      var txn = db.transaction('test', idbModeReadWrite);
      await txn.objectStore('test').put(1, 'key');
      await txn.completed;
      txn = db.transaction('test', idbModeReadOnly);
      expect(await txn.objectStore('test').getObject('key'), 1);
      await txn.completed;
    } finally {
      db.close();
    }
  }, timeout: const Timeout(Duration(seconds: 30)));
}
