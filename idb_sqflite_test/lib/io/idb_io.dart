import 'package:idb_shim/idb_shim.dart';
export 'package:idb_shim/idb_shim.dart';
import 'package:idb_sqflite/idb_client_sqflite.dart';
import 'package:sqflite/sqflite.dart';

IdbFactory get idbFactory => getIdbFactorySqflite(databaseFactory);
