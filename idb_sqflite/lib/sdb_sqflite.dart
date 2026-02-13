/// SDB on top of sqflite.
///
/// This library provides a simplified database API ([SdbFactory]) on top of sqflite,
/// making it easy to use a lightweight database in Flutter and Dart VM applications.
/// It acts as a bridge between the `idb_shim`'s SDB API and the `sqflite`
/// database implementation.
///
/// To use, import `package:idb_sqflite/sdb_sqflite.dart`.
library;

import 'package:idb_shim/sdb/sdb.dart';
import 'package:sqflite_common/sqflite.dart' as sqflite;

import 'idb_client_sqflite.dart';

// Re-export main idb and sdb APIs for convenience for the developer.
export 'package:idb_shim/idb_shim.dart';
export 'package:idb_shim/sdb.dart';
// Re-export sqflite specific features like inMemoryDatabasePath.
export 'package:sqflite_common/sqlite_api.dart' show inMemoryDatabasePath;

// Re-export the sqflite idb factory implementation.
export 'idb_client_sqflite.dart';

/// Creates a [SdbFactory] from a given sqflite [sqflite.DatabaseFactory].
///
/// This is useful for specifying a non-default sqflite factory, such as
/// `databaseFactoryFfi` for Dart VM (desktop) applications or for testing.
///
/// Example (using FFI for desktop):
/// ```dart
/// import 'package:sqflite_common_ffi/sqflite_ffi.dart';
/// import 'package:idb_sqflite/sdb_sqflite.dart';
///
/// void main() {
///   sqfliteFfiInit();
///   var factory = sdbFactoryFromSqflite(databaseFactoryFfi);
///   // ...use the factory to open a database.
/// }
/// ```
SdbFactory sdbFactoryFromSqflite(sqflite.DatabaseFactory databaseFactory) {
  return sdbFactoryFromIdb(getIdbFactorySqflite(databaseFactory));
}

/// The default [SdbFactory] for sqflite.
///
/// This factory uses the default `sqflite` database factory, which is suitable
/// for Flutter mobile applications (iOS and Android).
///
/// For Dart VM applications (e.g., desktop), you should create a new factory
/// using [sdbFactoryFromSqflite] with `databaseFactoryFfi` from the
/// `sqflite_common_ffi` package.
SdbFactory sdbFactorySqflite = sdbFactoryFromSqflite(sqflite.databaseFactory);
