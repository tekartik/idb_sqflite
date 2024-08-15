import 'package:sqflite_common/sqlite_api.dart' as sqflite;

/// Global store
final String globalStoreDbName = 'com.tekartik.idb.global_store';

/// Global store table
final String databaseTable = 'database';

/// Global store
class SqfliteGlobalStore {
  /// Global store
  SqfliteGlobalStore(this.sqfliteDatabaseFactory);

  /// sqflite database factory
  final sqflite.DatabaseFactory sqfliteDatabaseFactory;

  /// Database name
  var dbName = globalStoreDbName;

  sqflite.Database? _database;

  /// sqflite Database
  Future<sqflite.Database> get database async => _database ??= await () async {
        return sqfliteDatabaseFactory.openDatabase(dbName,
            options: sqflite.OpenDatabaseOptions(
                version: 1,
                onCreate: (db, _) async {
                  await db.execute('DROP TABLE IF EXISTS $databaseTable');
                  await db.execute(
                      'CREATE TABLE $databaseTable (name TEXT UNIQUE NOT NULL)');
                }));
      }();

  /// Get database names
  Future<List<String>> getDatabaseNames() async {
    var db = await database;
    return (await db.query(databaseTable, columns: ['name']))
        .map((map) => map['name'] as String)
        .toList(growable: false);
  }

  /// Return true if added
  Future<bool> addDatabaseName(String name) async {
    var db = await database;
    try {
      await db.insert(databaseTable, {'name': name});
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Delete a database name
  Future<bool> deleteDatabaseName(String name) async {
    var db = await database;
    try {
      var count =
          await db.delete(databaseTable, where: 'name = ?', whereArgs: [name]);
      return count > 0;
    } catch (e) {
      return false;
    }
  }
}
