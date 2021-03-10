import 'dart:io';

import 'package:process_run/shell.dart';
import 'package:pub_semver/pub_semver.dart';

Future main() async {
  var shell = Shell(workingDirectory: '..');

  await shell.run('flutter doctor');

  var nnbdEnabled = dartVersion > Version(2, 12, 0, pre: '0');
  if (nnbdEnabled) {
    for (var dir in [
      'idb_sqflite',
      'idb_sqflite_common_test',
      'idb_sqflite_test_app',
    ]) {
      shell = shell.pushd(dir);
      await shell.run('''
    
    pub get
    dart tool/travis.dart
    
        ''');
      shell = shell.popd();
    }
  } else {
    stderr.writeln('ci test skipped for $dartVersion');
  }

  // Old to migrate
  // ignore: dead_code
  if (false) {
    for (var dir in <String>[
      'idb_sqflite_test',
    ]) {
      shell = shell.pushd(dir);
      await shell.run('''
    
    flutter packages get
    dart tool/travis.dart
    
        ''');
      shell = shell.popd();
    }
  }
}
