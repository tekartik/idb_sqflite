// @dart=2.9
import 'package:process_run/shell.dart';

Future<void> main() async {
  var shell = Shell();

  await shell.run('''

dart analyze --fatal-warnings --fatal-infos .
dart format -o none --set-exit-if-changed .

dart test
''');
}
