import 'package:sqflite/sqlite_api.dart' as sqflite;

final String globalStoreDbName = "com.tekartik.idb.global_store";

final String databaseTable = "database";

class SqfliteGlobalStore {
  SqfliteGlobalStore(this.sqfliteDatabaseFactory);

  final sqflite.DatabaseFactory sqfliteDatabaseFactory;

  var dbName = globalStoreDbName;

  sqflite.Database _database;
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

  Future<List<String>> getDatabaseNames() async {
    var db = await database;
    return (await db.query(databaseTable, columns: ['name']))
        .map((map) => map['name'] as String)
        .toList(growable: false);
  }

  // Return true if added
  Future<bool> addDatabaseName(String name) async {
    var db = await database;
    try {
      await db.insert(databaseTable, {'name': name});
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteDatabaseName(String name) async {
    var db = await database;
    try {
      int count =
          await db.delete(databaseTable, where: 'name = ?', whereArgs: [name]);
      return count > 0;
    } catch (e) {
      return false;
    }
  }

/*
  // To allow for proper schema migration if needed
  static const int INTERNAL_VERSION = 1;

  // can be changed for testing

  static String _DB_NAME = GLOBAL_STORE_DB_NAME;
  static String DB_VERSION = GLOBAL_STORE_DB_VERSION;
  static int DB_ESTIMATED_SIZE = GLOBAL_STORE_DB_ESTIMATED_SIZE;
  static String NAME_COLUMN_NAME = "name";
  static String DATABASES_TABLE_NAME = "databases";

  SqlDatabase db;

  Future addDatabaseName(String name) {
    Future<SqlResultSet> insert(SqlTransaction tx) {
      String insertSqlStatement =
          "INSERT INTO $DATABASES_TABLE_NAME ($NAME_COLUMN_NAME) VALUES(?)";
      List<String> insertSqlArguments = [name];
      return tx.execute(insertSqlStatement, insertSqlArguments);
    }

    Future<bool> checkExists(SqlTransaction tx) {
      return tx.selectCount("databases WHERE name = ?", [name]).then((count) {
        return count == 1;
      });
    }

    return _checkOpenTransaction().then((tx) {
      return checkExists(tx).then((exists) {
        if (!exists) {
          return insert(tx);
        }
      });
    });
  }

  Future deleteDatabaseName(String name) {
    return _checkOpenTransaction().then((tx) {
      String deleteSqlStatement =
          "DELETE FROM $DATABASES_TABLE_NAME WHERE $NAME_COLUMN_NAME ";
      List<String> deleteSqlArguments;
      if (name == null) {
        deleteSqlStatement += "IS NULL";
        deleteSqlArguments = [];
      } else {
        deleteSqlStatement += "= ?";
        deleteSqlArguments = [name];
      }

      return tx
          .execute(deleteSqlStatement, deleteSqlArguments)
          .then((SqlResultSet resultSet) {
        //print(resultSet.rowsAffected);
      });
    }).catchError((e) {
      // Ok to fail
      return null;
    });
  }

  /**
   * There is valid transaction right aways
   */
  Future<SqlTransaction> _checkOpenTransaction() {
    return _checkOpen().then((SqlTransaction tx) {
      if (tx == null) {
        return db.transaction();
      }
      return tx;
    });
  }

  Future<SqlTransaction> _checkOpen() {
    Completer completer = new Completer.sync();
    _checkOpenNew((SqlTransaction tx) {
      completer.complete(tx);
    });
    return completer.future;
  }

  void _checkOpenNew(void action(SqlTransaction tx)) {
    if (db == null) {
      db = sqlDatabaseFactory.openDatabase(
          dbName, DB_VERSION, dbName, DB_ESTIMATED_SIZE);
    }

    Future<SqlTransaction> _cleanup(SqlTransaction tx) {
      return tx.dropTableIfExists("version") //
          .then((_) {
        return tx.execute(
            "CREATE TABLE version (internal_version INT, signature TEXT)");
      }).then((_) {
        return tx.execute(
            "INSERT INTO version (internal_version, signature)" //
            " VALUES (?, ?)",
            [INTERNAL_VERSION, INTERNAL_SIGNATURE]);
      }).then((_) {
        return createDatabasesTable(tx).then((_) {
          return tx;
        });
      });
    }

    Future<SqlTransaction> _setup() {
      return db.transaction().then((tx) async {
        try {
          SqlResultSet rs = await tx
              .execute("SELECT internal_version, signature FROM version"); //
          if (rs.rows.length != 1) {
            return await _cleanup(tx);
          }
          int internalVersion = getInternalVersionFromResultSet(rs);
          String signature = getSignatureFromResultSet(rs);
          if (signature != INTERNAL_SIGNATURE) {
            return await _cleanup(tx);
          }
          if (internalVersion != INTERNAL_VERSION) {
            return await _cleanup(tx);
          }
          return tx;
        } catch (_) {
          //return db.transaction().then((tx) {
          return await _cleanup(tx);
          //});
        }
      });
    }

    _setup().then((tx) {
      action(tx);
    });
  }

   */
}
