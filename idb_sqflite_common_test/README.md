# idb_sqflite_common_test

Shared test suites for [idb_sqflite](../idb_sqflite) (IndexedDB on sqflite).
Combine them with the generic IndexedDB and sdb suites of `idb_test` to test
idb_sqflite on a sqflite `DatabaseFactory`: sqflite_common_ffi on the Dart VM,
the sqflite plugin on a device. Test only, not on pub.dev.

## Getting started

```yaml
dev_dependencies:
  idb_sqflite_common_test:
    git:
      url: https://github.com/tekartik/idb_sqflite
      path: idb_sqflite_common_test
    version: '>=0.2.0'
  idb_test:
    git:
      url: https://github.com/tekartik/idb_shim.dart
      path: idb_test
  idb_sqflite: '>=1.5.3'
  sqflite_common_ffi: '>=2.3.0'
  test:
```

`test/idb_sqflite_ffi_test.dart`:

```dart
@TestOn('vm')
library;

import 'package:idb_sqflite/idb_sqflite.dart';
import 'package:idb_sqflite_common_test/idb_sqflite_test.dart'
    as idb_sqflite_test;
import 'package:idb_test/idb_test_common.dart';
import 'package:idb_test/test_runner.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

void main() {
  ffi.sqfliteFfiInit();
  var context = TestContext(
    factory: getIdbFactorySqflite(ffi.databaseFactoryFfi),
  );
  group('idb_sqflite_ffi', () {
    // Generic IndexedDB and sdb suites, regression suites included (idb_test).
    defineAllTests(context);
    // sqflite specific tests (this package).
    idb_sqflite_test.defineTests(context.factory);
  });
}
```

Run it with `dart test -p vm` (on Linux, sqflite_common_ffi needs
`libsqlite3`).

## Entry points

| Library | Function | Takes |
|---|---|---|
| `idb_sqflite_test.dart` | `defineTests` | the idb_sqflite `IdbFactory` (sqlite tables, index tables, parallel inserts) |
| `sdb_sqflite_test.dart` | `defineSdbSqfliteTests` | the `SdbFactory` (`sdbFactoryFromSqflite`): in memory, missing folders |
| `sqflite_transaction_wrapper_test.dart` | `defineTests` | the sqflite `DatabaseFactory` |

Who runs them: `test/` of this package (ffi, ffi sandbox), and
`idb_sqflite_test_app` (a Flutter app, the plugin factory).

## Common pitfalls

* Two libraries name their function `defineTests`: import them with a prefix.
* `sqflite_transaction_wrapper_test.dart` registers a `setUp` / `tearDown`:
  call it inside its own `group`, or they run around every test of yours.
* The suites reuse fixed database names: `concurrency: 1` in
  `dart_test.yaml`, or a `sandbox(path: ...)` factory per test file.
* idb_shim 2.11.3 at least: the idb_test regression suites check its fixes.
* VM and devices only: idb_sqflite has no web backend.

Agent skill: [skills/idb-sqflite-common-test-suite](skills/idb-sqflite-common-test-suite/SKILL.md).
