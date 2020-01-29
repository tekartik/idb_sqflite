import 'package:process_run/shell.dart';

/// Run unit and driver test on a connected device
Future main() async {
  var shell = Shell();

  shell = shell.pushd('idb_sqflite');
  await shell.run('''
    
    flutter test
    
        ''');

  shell = shell.popd();
  shell = shell.pushd('idb_sqflite_test');
  await shell.run('''
    
    flutter packages get
    flutter test
    dart tool/run_flutter_driver_test.dart
    
        ''');
  shell = shell.popd();
  shell = shell.popd();
}
