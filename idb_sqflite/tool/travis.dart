import 'package:process_run/shell.dart';

Future<void> main() async {
  var shell = Shell();

  await shell.run('''

flutter analyze
flutter test

''');

  shell = shell.pushd('example');

  await shell.run('''

flutter analyze

''');
}
