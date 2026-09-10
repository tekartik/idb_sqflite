---
name: idb-sqflite-setup
description: >-
  Use when wiring package:idb_sqflite, the IndexedDB (idb_shim) implementation
  stored in SQLite through sqflite: getIdbFactorySqflite(databaseFactory),
  idbFactorySqflite, sdbFactoryFromSqflite, sdbFactorySqflite, choosing the
  sqflite factory per platform (sqflite plugin on iOS/Android/macOS,
  sqflite_common_ffi databaseFactoryFfi on Linux/Windows, Dart VM and tests,
  idbFactoryNative on the web through a conditional import), database names
  and paths (getDatabasesPath, absolute paths, inMemoryDatabasePath, sandbox,
  getDatabaseFullPath, deleteDatabase) and the sqflite-specific limits on key
  and value types. Does not describe the IndexedDB API itself.
---

# idb_sqflite: IndexedDB on top of sqflite

`package:idb_sqflite` gives an `IdbFactory` (the `idb_shim` IndexedDB API) whose
databases are SQLite files managed by a sqflite `DatabaseFactory`. Use it on
Flutter iOS/Android/macOS with the `sqflite` plugin, and on Linux/Windows, the
Dart VM and in unit tests with `sqflite_common_ffi`. It does not run on the
web: use `idbFactoryNative` from `idb_shim` there. This skill only covers the
sqflite wiring; for the IndexedDB API (open, transactions, stores, indexes,
cursors) and the SDB API, use the `idb-shim-*` skills shipped by `idb_shim`.

```dart
import 'package:idb_sqflite/idb_sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show sqfliteFfiInit, databaseFactoryFfi;

Future<void> main() async {
  sqfliteFfiInit(); // Dart VM, desktop, tests
  final IdbFactory idbFactory = getIdbFactorySqflite(databaseFactoryFfi);
  final db = await idbFactory.open('app.db', version: 1,
      onUpgradeNeeded: (e) => e.database.createObjectStore('notes', autoIncrement: true));
  db.close();
}
```

## Guidelines

### Imports

* `package:idb_sqflite/idb_sqflite.dart` re-exports all of
  `package:idb_shim/idb_shim.dart` (`IdbFactory`, `Database`, `idbModeReadWrite`,
  `idbFactoryNative`, `idbFactoryMemory`, `sandbox`...) plus
  `getIdbFactorySqflite` and `idbFactorySqflite`. One import is enough for an
  io-only file.
* `package:idb_sqflite/idb_client_sqflite.dart` exports only
  `getIdbFactorySqflite` and `idbFactorySqflite`. Use it in a file that already
  imports `package:idb_shim/idb_shim.dart`, typically the io side of a
  conditional import.
* `package:idb_sqflite/sdb_sqflite.dart` re-exports `idb_shim.dart`,
  `package:idb_shim/sdb.dart`, the two idb factory helpers, plus
  `sdbFactoryFromSqflite`, `sdbFactorySqflite` and sqflite's
  `inMemoryDatabasePath`. Use it when the app uses the SDB API.
* The sqflite `DatabaseFactory` type and the `databaseFactory` global come from
  `package:sqflite/sqflite.dart` (Flutter plugin) or
  `package:sqflite_common_ffi/sqflite_ffi.dart` (both re-export
  `sqflite_common`). `idb_sqflite` depends only on `sqflite_common`, so add
  `sqflite` and/or `sqflite_common_ffi` to your own `pubspec.yaml`.
* sqflite and idb_shim both export `Database`, `Transaction` and
  `DatabaseException`. In a file that imports both, import the sqflite side
  with `show sqfliteFfiInit, databaseFactoryFfi, databaseFactory` (or `as
  sqflite`) so that the unprefixed names are the IndexedDB ones.

### Creating the factory

* `getIdbFactorySqflite(sqfliteDatabaseFactory)` builds an `IdbFactory` from any
  sqflite factory (`databaseFactory`, `databaseFactoryFfi`,
  `databaseFactoryFfiNoIsolate`, `databaseFactorySqflitePlugin`). Prefer it,
  pass the factory explicitly, and create it once (global or provider).
* `idbFactorySqflite` is a top-level variable initialized lazily from sqflite's
  global `databaseFactory` on first access. It throws `StateError
  ("databaseFactory not initialized")` when no sqflite factory is set, and it
  keeps the factory it saw first. On Linux/Windows/VM set
  `databaseFactory = databaseFactoryFfi` (after `sqfliteFfiInit()`) before
  touching it.
* On Flutter iOS/Android/macOS the `sqflite` plugin registers itself as the
  default `databaseFactory` at startup, so `getIdbFactorySqflite(databaseFactory)`
  and `idbFactorySqflite` need no setup. On Linux/Windows the plugin does not
  exist: use `sqflite_common_ffi` (`sqfliteFfiInit()` then
  `databaseFactoryFfi`), or depend on the `sqflite_ffi` Flutter plugin, which
  registers `sqfliteDatabaseFactoryFfi` as the default automatically.
* SDB: `sdbFactoryFromSqflite(sqfliteDatabaseFactory)` and the lazily
  initialized `sdbFactorySqflite` mirror the two idb helpers and return an
  `SdbFactory` (same as `sdbFactoryFromIdb(getIdbFactorySqflite(...))`).

### Cross platform apps (web + mobile + desktop)

* Split platform code with a conditional import or export:
  `export 'db_factory_io.dart' if (dart.library.js_interop) 'db_factory_web.dart';`.
  Both files expose the same `IdbFactory get idbFactory` (or `SdbFactory`).
  The io file imports `idb_sqflite`, the web file returns `idbFactoryNative`
  (or `idbFactoryWeb`) from `idb_shim`. The rest of the app only sees
  `IdbFactory`.
* Never import `idb_sqflite` or `sqflite_common_ffi` from a file compiled for
  the web (`dart:ffi`/`dart:io` do not compile there). `kIdbDartIsWeb`
  (idb_shim) and `kSdbDartIsWeb` only help at runtime in code that already
  compiles on both platforms.
* Inside the io file, branch on `Platform.isLinux || Platform.isWindows` to set
  `databaseFactory = databaseFactoryFfi`, then use
  `getIdbFactorySqflite(databaseFactory)` for every io platform.

### Database names and paths

* A relative name (`'app.db'`) is resolved by sqflite under
  `await sqfliteDatabaseFactory.getDatabasesPath()`: the app databases directory
  on mobile, `.dart_tool/sqflite_common_ffi/databases` (relative to the current
  directory) with ffi. Change it with `databaseFactory.setDatabasesPath(dir)` or
  wrap the idb factory with `sandbox(path: dir)`.
* An absolute path is used as-is; missing parent directories are created. On
  Flutter desktop compute one from `path_provider`
  (`getApplicationSupportDirectory()`) and either pass absolute names or use
  `idbFactory.sandbox(path: join(dir.path, 'databases'))`.
* `idbFactory.sandbox(path: ...)` (idb_shim extension, works on any factory)
  returns an `IdbFactory` whose databases all live below `path`; a relative
  sandbox path is itself resolved under the sqflite databases path.
* `await idbFactory.getDatabaseFullPath(name)` returns the file path that
  `open(name)` uses (absolute paths and `inMemoryDatabasePath` come back
  unchanged). Use it for logging, backups and tests.
* `inMemoryDatabasePath` (`':memory:'`, from `sqflite_common`, re-exported by
  `sdb_sqflite.dart`) opens a private in-memory SQLite database: content is
  lost on `close()`, and the name is never sandboxed.
* `await idbFactory.deleteDatabase(name)` deletes the SQLite file through
  sqflite. Close every open `Database` for that name first.
* `getDatabaseNames()` throws `UnsupportedError` and `supportsDatabaseNames`
  is `false`: keep your own list of database names.
* Opening with a lower version than the file throws
  `StateError('cannot downgrade ...')`. Use `idbFactory.openOnDowngradeDelete(...)`
  (idb_shim `IdbFactoryExt`) when an older build should wipe the data instead.
* Store and index names are used unquoted in SQL table names (`s__<store>`,
  `<store>__<index>`). Use identifier-like names: letters, digits and `_`, no
  spaces, dashes or dots.

### Keys and values (sqflite limits)

* Keys are `String`, `int` or a non-empty `List` of those (composite keys and
  array `keyPath`s are supported). `double` keys are not supported
  (`supportsDoubleKey` is `false`) and `DateTime` is not a valid key: store a
  millisecond `int` or an ISO string instead.
* Values are JSON-encoded in a BLOB column. Supported value types: `null`,
  `bool`, `num`, `String`, `List`, `Map` with `String` keys, `DateTime` and
  `Uint8List` (nested at any depth). Anything else (custom classes, `Set`,
  `Duration`, `Map` with non-string keys) makes `put`/`add` throw
  `ArgumentError(... not supported)`. Convert models to maps first (for
  example with `package:cv`).
* `DateTime` round-trips as an instant and is always read back in UTC
  (`isUtc == true`); `Uint8List` is read back as `Uint8List`. A `Map` whose
  only key starts with `@` is reserved for this encoding and is escaped
  transparently.
* An index with `multiEntry: true` and an array `keyPath` throws
  `UnsupportedError` at `createIndex`.

### Transactions and schema

* Every `db.transaction(...)` maps to one sqflite transaction (readonly too).
  It commits as soon as no idb operation is pending and the current event
  completes: keep only database work between operations. Awaiting an
  unrelated future (`Future.delayed`, HTTP, a dialog) inside a transaction lets
  it commit, and the next operation throws `TransactionInactiveError`.
* `await txn.completed` before using results outside the transaction;
  `txn.abort()` rolls back.
* Schema changes (`createObjectStore`, `deleteObjectStore`, `createIndex`,
  `deleteIndex`) are only valid inside `onUpgradeNeeded`. They are applied to
  SQLite when the version-change transaction ends, or before the first
  read/write of a freshly created store in that same callback.

### Tests

* In `package:test` files call `sqfliteFfiInit()` once (in `main` or
  `setUpAll`) and build the factory with
  `getIdbFactorySqflite(databaseFactoryFfi)`. Put test databases in a sandbox
  such as `.dart_tool/<pkg>/test` and `deleteDatabase` in `setUp`. Mark the
  file `@TestOn('vm')`.

## Examples

### Dart VM / desktop / test: factory from sqflite_common_ffi

```dart
import 'package:idb_sqflite/idb_sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show sqfliteFfiInit, databaseFactoryFfi;

Future<void> main() async {
  sqfliteFfiInit();
  final idbFactory = getIdbFactorySqflite(databaseFactoryFfi);
  const storeName = 'records';

  final db = await idbFactory.open(
    'my_records.db', // under .dart_tool/sqflite_common_ffi/databases
    version: 1,
    onUpgradeNeeded: (VersionChangeEvent event) {
      event.database.createObjectStore(storeName, autoIncrement: true);
    },
  );

  var txn = db.transaction(storeName, idbModeReadWrite);
  final key = await txn.objectStore(storeName).put({'some': 'data'});
  await txn.completed;

  txn = db.transaction(storeName, idbModeReadOnly);
  final value = await txn.objectStore(storeName).getObject(key);
  await txn.completed;
  print(value); // {some: data}
  db.close();
}
```

### Flutter: plugin on mobile, ffi on Linux/Windows

```dart
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:idb_sqflite/idb_sqflite.dart';
import 'package:sqflite/sqflite.dart' show databaseFactory;
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show sqfliteFfiInit, databaseFactoryFfi;

late final IdbFactory idbFactory;

void initDatabaseFactory() {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isLinux || Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  // iOS/Android/macOS: databaseFactory is the sqflite plugin factory.
  idbFactory = getIdbFactorySqflite(databaseFactory);
}
```

### Cross platform app with a conditional export

`lib/src/db_factory.dart`:

```dart
export 'db_factory_io.dart' if (dart.library.js_interop) 'db_factory_web.dart';
```

`lib/src/db_factory_io.dart`:

```dart
import 'dart:io';

import 'package:idb_shim/idb_shim.dart';
import 'package:idb_sqflite/idb_client_sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show sqfliteFfiInit, databaseFactoryFfi, databaseFactory;

IdbFactory get idbFactory {
  if (Platform.isLinux || Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  return getIdbFactorySqflite(databaseFactory);
}
```

`lib/src/db_factory_web.dart`:

```dart
import 'package:idb_shim/idb_shim.dart';

IdbFactory get idbFactory => idbFactoryNative;
```

Application code imports `db_factory.dart` and only uses `IdbFactory`.

### Paths: sandbox, absolute path, in-memory, delete

```dart
import 'package:idb_sqflite/sdb_sqflite.dart'; // also exports inMemoryDatabasePath
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show sqfliteFfiInit, databaseFactoryFfi;

Future<void> main() async {
  sqfliteFfiInit();
  final base = getIdbFactorySqflite(databaseFactoryFfi);

  // Relative name: <databasesPath>/app.db
  print(await base.getDatabaseFullPath('app.db'));

  // All databases of this factory below .dart_tool/my_app/db
  final idbFactory = base.sandbox(path: p.join('.dart_tool', 'my_app', 'db'));
  print(await idbFactory.getDatabaseFullPath('app.db'));

  // Absolute path: used as is (directory created on open)
  final absolute = p.absolute(p.join('.dart_tool', 'my_app', 'other.db'));
  final db = await base.open(absolute, version: 1,
      onUpgradeNeeded: (e) => e.database.createObjectStore('s'));
  db.close();
  await base.deleteDatabase(absolute);

  // Private in-memory database, gone on close()
  final memDb = await base.open(inMemoryDatabasePath, version: 1,
      onUpgradeNeeded: (e) => e.database.createObjectStore('s'));
  memDb.close();
}
```

### Values: DateTime and bytes round trip, unsupported types

```dart
import 'dart:typed_data';

import 'package:idb_sqflite/idb_sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show sqfliteFfiInit, databaseFactoryFfi;

Future<void> main() async {
  sqfliteFfiInit();
  final idbFactory = getIdbFactorySqflite(databaseFactoryFfi);
  final db = await idbFactory.open('values.db', version: 1,
      onUpgradeNeeded: (e) => e.database.createObjectStore('items'));

  var txn = db.transaction('items', idbModeReadWrite);
  var store = txn.objectStore('items');
  await store.put({
    'when': DateTime(2024, 1, 2, 3, 4, 5), // read back as UTC
    'bytes': Uint8List.fromList([1, 2, 3]),
    'nested': {'tags': ['a', 'b'], 'count': 1},
  }, 'item1');
  try {
    await store.put({'d': const Duration(seconds: 1)}, 'bad');
  } on ArgumentError catch (e) {
    print('not supported: $e');
  }
  await txn.completed;

  txn = db.transaction('items', idbModeReadOnly);
  final map = (await txn.objectStore('items').getObject('item1')) as Map;
  await txn.completed;
  print((map['when'] as DateTime).isUtc); // true
  print(map['bytes'] is Uint8List); // true
  db.close();
}
```

### SDB API on sqflite

```dart
import 'package:idb_sqflite/sdb_sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show sqfliteFfiInit, databaseFactoryFfi;

final notes = SdbStoreRef<int, SdbModel>('notes');

Future<void> main() async {
  sqfliteFfiInit();
  final sdbFactory = sdbFactoryFromSqflite(databaseFactoryFfi);
  final db = await sdbFactory.openDatabase(
    'notes.db',
    options: SdbOpenDatabaseOptions(
      version: 1,
      schema: SdbDatabaseSchema(stores: [notes.schema(autoIncrement: true)]),
    ),
  );
  final key = await notes.add(db, {'title': 'hello'});
  print(await notes.record(key).get(db));
  await db.close();
}
```

### Unit test with a sandboxed ffi factory

```dart
@TestOn('vm')
library;

import 'package:idb_sqflite/idb_sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show sqfliteFfiInit, databaseFactoryFfi;
import 'package:test/test.dart';

void main() {
  late IdbFactory idbFactory;
  const dbName = 'counter.db';

  setUpAll(() {
    sqfliteFfiInit();
    idbFactory = getIdbFactorySqflite(databaseFactoryFfi)
        .sandbox(path: p.absolute(p.join('.dart_tool', 'my_pkg', 'test')));
  });
  setUp(() => idbFactory.deleteDatabase(dbName));

  test('persists across open', () async {
    Future<Database> open() => idbFactory.open(dbName, version: 1,
        onUpgradeNeeded: (e) => e.database.createObjectStore('kv'));
    var db = await open();
    var txn = db.transaction('kv', idbModeReadWrite);
    await txn.objectStore('kv').put(1, 'count');
    await txn.completed;
    db.close();

    db = await open();
    txn = db.transaction('kv', idbModeReadOnly);
    expect(await txn.objectStore('kv').getObject('count'), 1);
    await txn.completed;
    db.close();
  });
}
```

## Common mistakes

* Reading `idbFactorySqflite` (or `sdbFactorySqflite`) on the VM before
  `databaseFactory = databaseFactoryFfi`: `StateError: databaseFactory not
  initialized`. Prefer `getIdbFactorySqflite(databaseFactoryFfi)`.
* Forgetting `sqfliteFfiInit()` before using `databaseFactoryFfi` on the VM or
  Flutter desktop.
* Importing `idb_sqflite` from code compiled for the web. Use a conditional
  import and `idbFactoryNative` on the web.
* Ambiguous `Database`/`Transaction` when importing both idb_shim and sqflite
  without `show` or a prefix.
* Using a `double` or a `DateTime` as a key, or storing objects that are not
  JSON-like maps/lists (`ArgumentError ... not supported`).
* Expecting `DateTime` values to come back in local time; they are UTC.
* Awaiting network or UI work inside a transaction (`TransactionInactiveError`).
* Calling `getDatabaseNames()` (unsupported) or expecting sandboxed and
  in-memory databases to share files with the base factory.
* Store/index names with dashes, dots or spaces (used unquoted in SQL).

## More

See [references/storage.md](references/storage.md) for the SQLite layout used
by idb_sqflite (tables, columns, value encoding) when inspecting a database
file or debugging.
