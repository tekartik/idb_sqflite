import 'package:idb_shim/idb_shim.dart';
export 'package:idb_shim/idb_shim.dart';
import 'package:idb_shim/idb_client_native.dart';

IdbFactory get idbFactory => idbFactoryNative;
