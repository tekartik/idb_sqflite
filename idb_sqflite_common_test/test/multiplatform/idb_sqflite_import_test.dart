import 'dart:typed_data';

import 'package:idb_shim/idb_io.dart';
import 'package:idb_sqflite/idb_sqflite.dart' hide Database;
import 'package:idb_sqflite/src/env_utils.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:test/test.dart';

class _DatabaseFactoryMock implements DatabaseFactory {
  @override
  Future<bool> databaseExists(String path) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteDatabase(String path) {
    throw UnimplementedError();
  }

  @override
  Future<String> getDatabasesPath() {
    throw UnimplementedError();
  }

  @override
  Future<Database> openDatabase(String path, {OpenDatabaseOptions? options}) {
    throw UnimplementedError();
  }

  @override
  Future<void> setDatabasesPath(String path) {
    throw UnimplementedError();
  }

  @override
  Future<Uint8List> readDatabaseBytes(String path) {
    throw UnimplementedError();
  }

  @override
  Future<void> writeDatabaseBytes(String path, Uint8List bytes) {
    throw UnimplementedError();
  }
}

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
      getIdbFactorySqflite(_DatabaseFactoryMock());

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
