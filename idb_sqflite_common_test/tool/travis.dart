import 'package:process_run/shell.dart';

Future<void> main() async {
  Shell shell = Shell();

  await shell.run('''

  dartanalyzer --fatal-warnings --fatal-infos .
  dartfmt -n --set-exit-if-changed .

  pub run test -p vm -j 1

''');
}
