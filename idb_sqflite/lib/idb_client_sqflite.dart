library idb_client_sqflite;

import 'package:idb_shim/idb.dart';
import 'package:idb_sqflite/src/sqflite_factory.dart';
import 'package:sqflite_common/sqlite_api.dart' as sqflite;

/// Build the indexed db factory from a sqflite factory
IdbFactory getIdbFactorySqflite(sqflite.DatabaseFactory factory) =>
    IdbFactorySqflite(factory);
