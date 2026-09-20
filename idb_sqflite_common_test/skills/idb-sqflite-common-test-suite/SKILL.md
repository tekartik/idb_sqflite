---
name: idb-sqflite-common-test-suite
description: >-
  Use when running the shared idb_sqflite conformance test suites against a
  sqflite DatabaseFactory (sqflite_common_ffi databaseFactoryFfi, the sqflite
  Flutter plugin databaseFactory, databaseFactoryFfiNoIsolate): defineTests
  from idb_sqflite_test.dart, defineSdbSqfliteTests from sdb_sqflite_test.dart,
  defineTests from sqflite_transaction_wrapper_test.dart, building the
  TestContext that idb_test's defineAllTests / defineAllSdbTests need, sandbox
  factories (IdbFactorySandbox, SdbFactorySandbox), sqfliteFfiInit,
  inMemoryDatabasePath and the @TestOn('vm') / dart_test.yaml setup for those
  tests.
---

# idb_sqflite shared test suites (idb_sqflite_common_test)

`idb_sqflite_common_test` is a test-only helper package: it defines the
sqflite-specific test suites for `idb_sqflite` (SQLite layout, index tables,
multi entry stores, transaction wrapper, SDB paths) and is meant to be combined
with the generic IndexedDB suites of `idb_test`. It contains no runtime API:
every public library exposes a `define...Tests(...)` function you call from the
`main()` of your own `package:test` file.

## Guidelines

* Dependency (git only, never published on pub.dev). Add it, and the packages
  it is used with, to `dev_dependencies`:
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
    sqflite_common_ffi: '>=2.3.0'
    test:
  ```
  `idb_sqflite`, `idb_shim` and `sqflite_common` come with it, but declare the
  ones you import yourself.
* Three public libraries, each with one entry point:
  * `package:idb_sqflite_common_test/idb_sqflite_test.dart` →
    `void defineTests(IdbFactory factory)`: sqflite implementation details
    (in memory database, reopen after a transaction, `sqlite_master` tables
    created and dropped for a `multiEntry` index, index table content,
    parallel multi insert). It re-exports `package:idb_test/idb_test_common.dart`,
    so it also brings `group`, `test`, `expect`, `testStoreName`,
    `testNameIndex`, `testNameField`.
  * `package:idb_sqflite_common_test/sdb_sqflite_test.dart` →
    `void defineSdbSqfliteTests(SdbFactory factory)`: SDB on sqflite
    (`inMemoryDatabasePath`, opening an absolute path whose parent directory
    is missing).
  * `package:idb_sqflite_common_test/sqflite_transaction_wrapper_test.dart` →
    `void defineTests(sqflite.DatabaseFactory factory)`: takes the *sqflite*
    factory (not an `IdbFactory`) and exercises `SqfliteTransactionWrapper`.
* Two libraries export a symbol named `defineTests`. Always import them with a
  prefix (`as idb_sqflite_test`, `as transaction_wrapper`) as the package's own
  tests do.
* Pass a real `idb_sqflite` factory: `getIdbFactorySqflite(databaseFactory)`
  from `package:idb_sqflite/idb_client_sqflite.dart` (or the whole
  `idb_sqflite.dart`), and `sdbFactoryFromSqflite(databaseFactory)` from
  `package:idb_sqflite/sdb_sqflite.dart` for the SDB suite. `defineTests` casts
  the opened database to the sqflite implementation to read `sqlite_master`, so
  `idbFactoryMemory`, `idbFactoryNative` or a logger-wrapped factory make it
  fail. A `sandbox(path: ...)` factory is fine.
* Generic IndexedDB conformance lives in `idb_test`, not here. Build a
  `TestContext` (`package:idb_test/idb_test_common.dart`) with
  `TestContext(factory: ...)` and pass it to `defineAllTests(ctx)` /
  `defineAllSdbTests(ctx)` from `package:idb_test/test_runner.dart`; then add
  the suites of this package on `ctx.factory`. Subclass `TestContext` only to
  override a capability flag (`isInMemory`, `isIdbSembast`).
* Dart VM / desktop / CI: mark the file `@TestOn('vm')` and call
  `sqfliteFfiInit()` (from `package:sqflite_common_ffi/sqflite_ffi.dart`) once
  at the top of `main()`, before building any factory. `databaseFactoryFfi`
  runs SQLite in an isolate; `databaseFactoryFfiNoIsolate` is faster for bulk
  insert benchmarks.
* Flutter: the same calls work in an `integration_test` on a device, with
  `databaseFactory` from `package:sqflite/sqflite.dart` instead of the ffi one
  and `WidgetsFlutterBinding.ensureInitialized()` first. These suites never run
  on the web (`idb_sqflite` needs `dart:ffi`/`dart:io`).
* Databases are created relative to the sqflite databases path
  (`.dart_tool/sqflite_common_ffi/databases` with ffi). Wrap the factory with
  `.sandbox(path: 'sandbox')` to isolate a run; the SDB sandbox type
  `SdbFactorySandbox` is re-exported by
  `package:idb_sqflite_common_test/src/idb_sqflite_mixin.dart` when you need to
  name it.
* The suites delete and recreate fixed database names
  (`delete_database.db`, `impl_multi_entry`, `parallel_multi_insert`,
  `transaction_wrapper.db`). Run them with `concurrency: 1` in
  `dart_test.yaml`, or in their own sandbox, so two test files do not fight
  over the same files. `parallel_multi_insert` inserts 4000 records and has a
  5 minute timeout: expect a slow file.
* Run with `dart test -p vm` (add `dart run sqflite_common_ffi:setup` style
  native setup only if your platform needs it). Do not add these calls to a
  library file: they must be inside a `main()` of a `_test.dart` file.

## Examples

### Full idb suite on sqflite_common_ffi

```dart
@TestOn('vm')
library;

import 'package:idb_sqflite/idb_client_sqflite.dart';
import 'package:idb_sqflite_common_test/idb_sqflite_test.dart'
    as idb_sqflite_test;
import 'package:idb_sqflite_common_test/sqflite_transaction_wrapper_test.dart'
    as transaction_wrapper;
import 'package:idb_test/idb_test_common.dart';
import 'package:idb_test/test_runner.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

Future<void> main() async {
  ffi.sqfliteFfiInit();
  var sqfliteFactory = ffi.databaseFactoryFfi;

  group('sqflite_ffi', () {
    var context = TestContext(factory: getIdbFactorySqflite(sqfliteFactory));
    // Generic IndexedDB conformance (idb_test).
    defineAllTests(context);
    // sqflite specific behavior (this package).
    idb_sqflite_test.defineTests(context.factory);
    // SqfliteTransactionWrapper, on the raw sqflite factory.
    transaction_wrapper.defineTests(sqfliteFactory);
  });
}
```

### SDB suites

```dart
@TestOn('vm')
library;

import 'package:idb_sqflite/sdb_sqflite.dart';
import 'package:idb_sqflite_common_test/sdb_sqflite_test.dart';
import 'package:idb_test/idb_test_common.dart';
import 'package:idb_test/test_runner.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

Future<void> main() async {
  ffi.sqfliteFfiInit();

  var sdbFactory = sdbFactoryFromSqflite(ffi.databaseFactoryFfi);
  // SDB conformance (idb_test) needs the matching IdbFactory.
  defineAllSdbTests(TestContext(factory: getIdbFactorySqflite(ffi.databaseFactoryFfi)));
  // sqflite specific SDB tests (this package).
  defineSdbSqfliteTests(sdbFactory);
}
```

### Same suites in a sandbox directory

```dart
@TestOn('vm')
library;

import 'package:idb_sqflite/idb_sqflite.dart';
import 'package:idb_sqflite/sdb_sqflite.dart';
import 'package:idb_sqflite_common_test/idb_sqflite_test.dart'
    as idb_sqflite_test;
import 'package:idb_sqflite_common_test/sdb_sqflite_test.dart';
import 'package:idb_sqflite_common_test/src/idb_sqflite_mixin.dart'
    show SdbFactorySandbox;
import 'package:idb_test/idb_test_common.dart';
import 'package:idb_test/test_runner.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

Future<void> main() async {
  ffi.sqfliteFfiInit();

  var context = TestContext(
    factory: getIdbFactorySqflite(ffi.databaseFactoryFfi).sandbox(path: 'sandbox'),
  );
  group('sandbox_sqflite_ffi', () {
    defineAllTests(context);
    idb_sqflite_test.defineTests(context.factory);
  });

  var sdbFactory =
      sdbFactoryFromSqflite(ffi.databaseFactoryFfi).sandbox(path: 'sandbox')
          as SdbFactorySandbox;
  group('sdb_sandbox_sqflite_ffi', () {
    defineSdbSqfliteTests(sdbFactory);
  });
}
```

### Only the transaction wrapper suite

```dart
@TestOn('vm')
library;

import 'package:idb_sqflite_common_test/sqflite_transaction_wrapper_test.dart'
    as transaction_wrapper;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:test/test.dart';

Future<void> main() async {
  ffi.sqfliteFfiInit();
  group('transaction_wrapper', () {
    transaction_wrapper.defineTests(ffi.databaseFactoryFfi);
  });
}
```

### dart_test.yaml for a package running these suites

```yaml
concurrency: 1
platforms:
  - vm
```

## Common mistakes

* Importing `idb_sqflite_test.dart` and `sqflite_transaction_wrapper_test.dart`
  without prefixes: both declare `defineTests`.
* Passing the sqflite `DatabaseFactory` to `idb_sqflite_test.defineTests`, or
  an `IdbFactory` to `transaction_wrapper.defineTests`.
* Passing `idbFactoryMemory`/`idbFactoryNative` (or a factory wrapped by
  `getIdbFactoryLogger`) to `defineTests`: it reads the SQLite schema of the
  real implementation.
* Forgetting `sqfliteFfiInit()` before `databaseFactoryFfi`, or forgetting
  `@TestOn('vm')` in a package whose `dart_test.yaml` also lists `chrome`.
* Running several of these test files concurrently on the same databases path.
