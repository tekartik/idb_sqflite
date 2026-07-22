import 'package:process_run/shell.dart' hide prompt;
import 'package:tekartik_app_dev_menu/dev_menu.dart';

//import '
var deviceIdVar = 'DEVICE_ID'.kvFromVar(defaultValue: 'emulator-5554');

Future main(List<String> arguments) async {
  await mainMenu(arguments, () {
    keyValuesMenu('vars', [deviceIdVar]);

    item('Run main_test_runner', () async {
      await run(
        '''flutter run -d ${deviceIdVar.value} -t lib/main_test_runner.dart''',
      );
    });
    item('Run main_test_runner_ffi', () async {
      await run(
        '''flutter run -d ${deviceIdVar.value} -t lib/main_test_runner_ffi.dart''',
      );
    });
  });
}
