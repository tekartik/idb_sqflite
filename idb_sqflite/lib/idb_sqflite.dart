/// The IndexedDB API of idb_shim stored in SQLite through sqflite.
///
/// Exports the whole `package:idb_shim/idb_shim.dart` API and
/// [getIdbFactorySqflite], which builds an [IdbFactory] on a sqflite
/// `DatabaseFactory`: the sqflite plugin `databaseFactory` on Flutter
/// Android, iOS and macOS, `databaseFactoryFfi` (sqflite_common_ffi, after
/// `sqfliteFfiInit()`) on Windows, Linux and the Dart VM. Not for the web,
/// use `idbFactoryNative` there.
///
/// ```dart
/// import 'package:idb_sqflite/idb_sqflite.dart';
/// import 'package:sqflite_common_ffi/sqflite_ffi.dart'
///     show databaseFactoryFfi, sqfliteFfiInit;
///
/// Future<void> main() async {
///   sqfliteFfiInit();
///   var idbFactory = getIdbFactorySqflite(databaseFactoryFfi);
///   var db = await idbFactory.open(
///     'my_records.db',
///     version: 1,
///     onUpgradeNeeded: (event) =>
///         event.database.createObjectStore('records', autoIncrement: true),
///   );
///   db.close();
/// }
/// ```
library;

import 'package:idb_shim/idb_shim.dart';
import 'package:idb_sqflite/idb_client_sqflite.dart';

export 'package:idb_shim/idb_shim.dart';

export 'idb_client_sqflite.dart';
