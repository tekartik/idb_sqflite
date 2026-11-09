/// [getIdbFactorySqflite] and [idbFactorySqflite] only, for a file that
/// already imports `package:idb_shim/idb_shim.dart`.
library;

import 'package:idb_shim/idb.dart';
import 'package:idb_sqflite/src/sqflite_factory.dart';
import 'package:sqflite_common/sqflite.dart' as sqflite;

/// Builds an [IdbFactory] storing each database in a SQLite file opened by
/// [factory] (a sqflite `DatabaseFactory`).
///
/// A relative database name is a file in the databases folder of [factory]
/// (`getDatabasesPath()`), an absolute path is used as is and
/// `inMemoryDatabasePath` is a private database in memory. Create it once and
/// keep it.
IdbFactory getIdbFactorySqflite(sqflite.DatabaseFactory factory) =>
    IdbFactorySqfliteImpl(factory);

/// The [IdbFactory] on the global sqflite `databaseFactory`.
///
/// Built the first time it is read, with the global factory of that time
/// (the sqflite plugin on Flutter Android, iOS and macOS): reading it before
/// the global factory is set throws a `StateError`. Prefer
/// [getIdbFactorySqflite] with an explicit factory.
IdbFactory idbFactorySqflite = getIdbFactorySqflite(sqflite.databaseFactory);
