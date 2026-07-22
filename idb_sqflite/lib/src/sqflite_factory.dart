// ignore_for_file: implementation_imports
import 'package:idb_shim/idb.dart';
import 'package:idb_shim/src/common/common_factory.dart';
import 'package:idb_shim/src/common/common_value.dart';
import 'package:idb_sqflite/src/sqflite_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common/sqlite_api.dart' as sqflite;

/// idb_sqflite factory name
const String idbFactoryNameSqflite = 'sqflite';

/// idb_sqflite factory class
class IdbFactorySqflite extends IdbFactoryBase {
  /// idb_sqflite factory
  IdbFactorySqflite(this.sqfliteDatabaseFactory);

  /// sqflite database factory
  final sqflite.DatabaseFactory sqfliteDatabaseFactory;
  @override
  bool get persistent => true;

  @override
  String get name => idbFactoryNameSqflite;

  @override
  Future<Database> open(
    String dbName, {
    int? version,
    OnUpgradeNeededFunction? onUpgradeNeeded,
    OnBlockedFunction? onBlocked,
  }) async {
    checkOpenArguments(version: version, onUpgradeNeeded: onUpgradeNeeded);

    try {
      var database = IdbDatabaseSqflite(this, dbName);
      await database.open(version, onUpgradeNeeded);
      return database;
    } catch (e) {
      // ignore: avoid_print
      print('fail to open $dbName ($e)');
      rethrow;
    }
  }

  @override
  Future<IdbFactory> deleteDatabase(
    String dbName, {
    OnBlockedFunction? onBlocked,
  }) async {
    var path = sanitizeDbName(dbName);
    await sqfliteDatabaseFactory.deleteDatabase(path);
    return this;
  }

  @override
  bool get supportsDatabaseNames {
    return false;
  }

  @override
  Future<List<String>> getDatabaseNames() => throw UnsupportedError(
    'IdbFactorySqflite.getDatabaseNames not supported',
  );

  // common implementation
  @override
  int cmp(Object first, Object second) => compareKeys(first, second);

  @override
  bool get supportsDoubleKey => false;

  @override
  Future<String> getDatabaseFullPath(String name) async {
    if (name == sqflite.inMemoryDatabasePath) {
      return name;
    }
    if (p.isAbsolute(name)) {
      return name;
    }
    var databasesPath = await sqfliteDatabaseFactory.getDatabasesPath();
    return p.join(databasesPath, name);
  }
}
