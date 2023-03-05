import 'dart:io';

import 'package:dev_test/package.dart';
import 'package:path/path.dart';
import 'package:process_run/shell.dart';
import 'package:pub_semver/pub_semver.dart';

Future main() async {
  final nnbdEnabled = dartVersion > Version(2, 12, 0, pre: '0');
  if (nnbdEnabled) {
    for (var dir in [
      'idb_sqflite_support',
      'idb_sqflite',
      'idb_sqflite_common_test',
      'idb_sqflite_test_app',
    ]) {
      await packageRunCi(join('..', dir));
    }
  } else {
    stderr.writeln('ci test skipped for $dartVersion');
  }
}
