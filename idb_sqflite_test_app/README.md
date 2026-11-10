# idb_sqflite_test_app

Flutter test app of [idb_sqflite](../idb_sqflite): it runs the shared
IndexedDB test suites (`idb_test`, `idb_sqflite_common_test`) on a device,
and holds two small counter apps.

Not published. The shared suites also run on the Dart VM (ffi) in
[idb_sqflite_common_test](../idb_sqflite_common_test): use this app for a
device (sqflite plugin) or a desktop app run.

## Setup

The platform folders are not committed: create the ones you need first.

```shell
flutter create . --platforms=android,ios,macos,linux,windows
```

## Run the test suites

The runners are `flutter run` targets: the results are printed in the
console (`All tests passed!` at the end), there is no exit code.

| Target | sqflite factory | Platforms |
|---|---|---|
| `lib/main_test_runner.dart` | the platform one: the plugin on Android, iOS, macOS; ffi on Linux, Windows | all but web |
| `lib/main_test_runner_ffi.dart` | ffi (`sqflite_ffi`), databases in the application support folder | all but web |

```shell
flutter run -d emulator-5554 -t lib/main_test_runner.dart
flutter run -d linux -t lib/main_test_runner_ffi.dart
```

The same from a menu: `dart run tool/test_menu.dart` (device id in the
`DEVICE_ID` variable, `emulator-5554` by default), or
`dart run tool/run_test_runner_linux.dart`.

`flutter test` runs the unit tests of the app (imports, runner context).

## Counter apps

* `lib/main.dart`: the idb API (`idbFactory`: idb_sqflite on io, the
  browser IndexedDB on the web).
* `lib/main_sdb.dart`: the sdb API (`sdbFactorySqflite`, `sdbFactoryWeb` on
  the web).

On Linux and Windows they set `databaseFactory = databaseFactoryFfi` first,
as an app must (no sqflite plugin there).
