import 'package:process_run/shell.dart';

Future main() async {
  var shell = Shell(workingDirectory: '..');

  await shell.run('flutter doctor');

  for (var dir in [
    'idb_sqflite',
  ]) {
    shell = shell.pushd(dir);
    await shell.run('''
    
    pub get
    dart tool/travis.dart
    
        ''');
    shell = shell.popd();
  }

  for (var dir in [
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
