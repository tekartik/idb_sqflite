import 'dart:async';

import 'package:flutter_driver/driver_extension.dart';

import '../test_common/idb_shim/test_runner.dart' as idb_shim_test;
import '../test_common/idb_sqflite_test_common.dart';

void main() {
  final Completer<String> completer = Completer<String>();
  enableFlutterDriverExtension(handler: (_) => completer.future);
  tearDownAll(() => completer.complete(null));

  group('driver', () {
    idb_shim_test.defineTests(testContextSqflite);
  });
}
