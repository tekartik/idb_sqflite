import 'dart:io';

import 'package:dev_test/test.dart';
import 'package:idb_sqflite/sdb_sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

//import '../idb_test_common.dart';

void main() {
  group('sdb_factory', () {
    test('init factory', () async {
      late SdbFactory factory;
      if (kSdbDartIsWeb) {
        factory = sdbFactoryWeb;
      } else {
        if (Platform.isWindows || Platform.isLinux) {
          // Use sqflite_common_ffi on Windows and Linux
          sqfliteFfiInit();
          databaseFactory = databaseFactoryFfi;
        }
        factory = sdbFactorySqflite;
      }

      var db = await factory.openDatabase('test.db');
      await db.close();
    });
  });
}
