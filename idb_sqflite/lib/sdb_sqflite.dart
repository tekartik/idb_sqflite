import 'package:idb_shim/sdb/sdb.dart';
import 'package:sqflite_common/sqflite.dart' as sqflite;

import 'idb_client_sqflite.dart';

export 'package:idb_shim/idb_shim.dart';
export 'package:idb_shim/sdb.dart';
export 'package:sqflite_common/sqlite_api.dart' show inMemoryDatabasePath;

export 'idb_client_sqflite.dart';

/// Factory from idb factory.
SdbFactory sdbFactoryFromSqflite(sqflite.DatabaseFactory databaseFactory) {
  return sdbFactoryFromIdb(getIdbFactorySqflite(databaseFactory));
}

/// Default factory using sqflite.
SdbFactory sdbFactorySqflite = sdbFactoryFromSqflite(sqflite.databaseFactory);
