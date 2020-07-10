import 'package:idb_shim/idb_shim.dart';
import 'package:idb_shim/idb_io.dart';
import 'package:idb_sqflite/idb_sqflite.dart';
import 'package:test/test.dart';
import 'package:idb_sqflite/src/env_utils.dart';

void main() {
  group('import', () {
    test('web', () {
      try {
        idbFactoryNative;
        if (!isRunningAsJavascript) {
          fail('should fail');
        }
      } on UnimplementedError catch (_) {}
    });

    test('io', () {
      getIdbFactorySqflite(null);

      try {
        idbFactorySembastIo;
        if (isRunningAsJavascript) {
          fail('should fail');
        }
      } on UnimplementedError catch (_) {}
    });

    test('memory', () {
      idbFactoryMemory;
      idbFactoryMemoryFs;
    });
  });
}
