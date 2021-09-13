import 'package:idb_shim/idb_client_native.dart';
import 'package:idb_shim/idb_shim.dart';

export 'package:idb_shim/idb_shim.dart';

IdbFactory get idbFactory => idbFactoryNative;
