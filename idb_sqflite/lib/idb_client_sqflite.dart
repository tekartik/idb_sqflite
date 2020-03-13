library idb_client_sqflite;

import 'package:idb_shim/idb.dart';
import 'package:idb_sqflite/src/sqflite_factory.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

@Deprecated('Use getIdbFactorySqflite(databaseFactory) instead.')

/// The indexedDB factory to use in flutter for an sqflite base implementation.
IdbFactory get idbFactorySqflite => IdbFactorySqflite(sqflite.databaseFactory);

/// Build the indexed db factory from a sqflite factory
IdbFactory getIdbFactorySqflite(sqflite.DatabaseFactory factory) =>
    IdbFactorySqflite(factory);
