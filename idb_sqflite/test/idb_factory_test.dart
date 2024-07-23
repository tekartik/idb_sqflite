import 'package:idb_sqflite/sdb_sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

//import '../idb_test_common.dart';

void main() {
  group('idb_factory', () {
    test('init factory', () async {
      late IdbFactory factory;
      if (kSdbDartIsWeb) {
        factory = idbFactoryNative;
      } else {
        // Use sqflite_common_ffi on Dart VM
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;

        // Set from the default sqflite factory
        factory = idbFactorySqflite;
      }

      var db = await factory.open('test.db');
      db.close();
    });
  });
}
