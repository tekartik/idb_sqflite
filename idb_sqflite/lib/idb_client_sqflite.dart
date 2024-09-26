library;

import 'package:idb_shim/idb.dart';
import 'package:idb_sqflite/src/sqflite_factory.dart';
import 'package:sqflite_common/sqflite.dart' as sqflite;

/// Build the indexed db factory from a sqflite factory
IdbFactory getIdbFactorySqflite(sqflite.DatabaseFactory factory) =>
    IdbFactorySqflite(factory);

/// The idb factory using the default sqflite factory (initialized either using
/// the plugin or manually)
IdbFactory idbFactorySqflite = getIdbFactorySqflite(sqflite.databaseFactory);
