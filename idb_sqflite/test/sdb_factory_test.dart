import 'package:idb_sqflite/sdb_sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

//import '../idb_test_common.dart';

void main() {
  group('sdb_factory', () {
    test('init factory', () async {
      late SdbFactory factory;
      if (kSdbDartIsWeb) {
        factory = sdbFactoryWeb;
      } else {
        // Use sqflite_common_ffi on Dart VM
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;

        // Set from the default sqflite factory
        factory = sdbFactorySqflite;
      }

      var db = await factory.openDatabase('test.db');
      await db.close();
    });
  });
}
