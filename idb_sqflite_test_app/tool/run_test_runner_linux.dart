import 'package:process_run/process_run.dart';

Future<void> main() async {
  await run('flutter run -d linux -t lib/main_test_runner_ffi.dart');
}
