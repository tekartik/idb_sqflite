library idb_client_sqflite;

import 'package:idb_shim/idb.dart';
import 'package:idb_sqflite/src/sqflite_factory.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

IdbFactory get idbFactorySqflite => IdbFactorySqflite(sqflite.databaseFactory);
