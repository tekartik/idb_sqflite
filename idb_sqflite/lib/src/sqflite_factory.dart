// ignore_for_file: implementation_imports
import 'package:idb_shim/idb.dart';
import 'package:idb_shim/src/common/common_factory.dart';
import 'package:idb_shim/src/common/common_value.dart';
import 'package:idb_sqflite/src/sqflite_database.dart';
import 'package:idb_sqflite/src/sqflite_global_store.dart';
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

  SqfliteGlobalStore? _globalStore;

  /// global store
  SqfliteGlobalStore get globalStore =>
      _globalStore ??= SqfliteGlobalStore(sqfliteDatabaseFactory);

  @override
  String get name => idbFactoryNameSqflite;

  set globalStoreDbName(String dbName) {
    globalStore.dbName = dbName;
  }

  @override
  Future<Database> open(
    String dbName, {
    int? version,
    OnUpgradeNeededFunction? onUpgradeNeeded,
    OnBlockedFunction? onBlocked,
  }) async {
    checkOpenArguments(version: version, onUpgradeNeeded: onUpgradeNeeded);

    var added = false;
    try {
      added = await globalStore.addDatabaseName(dbName);
      var database = IdbDatabaseSqflite(this, dbName);
      await database.open(version, onUpgradeNeeded);
      return database;
    } catch (e) {
      if (added) {
        await globalStore.deleteDatabaseName(dbName);
      }
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
    await globalStore.deleteDatabaseName(dbName);
    return this;
  }

  @override
  bool get supportsDatabaseNames {
    return true;
  }

  @override
  Future<List<String>> getDatabaseNames() => globalStore.getDatabaseNames();

  // common implementation
  @override
  int cmp(Object first, Object second) => compareKeys(first, second);

  @override
  bool get supportsDoubleKey => false;
}
