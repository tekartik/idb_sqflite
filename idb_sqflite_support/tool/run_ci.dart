//
// @dart = 2.9
//
// This is to allow running this file without null experiment
// In the future, remove this 2.9 comment or run using: dart --enable-experiment=non-nullable --no-sound-null-safety run tool/travis.dart

import 'dart:io';

import 'package:dev_test/package.dart';
import 'package:process_run/shell.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:path/path.dart';

Future main() async {
  final nnbdEnabled = dartVersion > Version(2, 12, 0, pre: '0');
  if (nnbdEnabled) {
    for (var dir in [
      'idb_sqflite',
      'idb_sqflite_common_test',
    ]) {
      await packageRunCi(join('..', dir));
    }
  } else {
    stderr.writeln('ci test skipped for $dartVersion');
  }
}
