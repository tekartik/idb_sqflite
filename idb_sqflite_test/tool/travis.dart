import 'package:process_run/shell.dart';

Future<void> main() async {
  Shell shell = Shell();

  await shell.run('''

flutter format --set-exit-if-changed lib test tool
flutter analyze --no-current-package lib test tool
flutter test

''');
}
