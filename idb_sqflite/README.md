# idb_sqflite

[![pub package](https://img.shields.io/pub/v/idb_sqflite.svg)](https://pub.dev/packages/idb_sqflite)
[![Run CI](https://github.com/tekartik/idb_sqflite/actions/workflows/run_ci_flutter.yml/badge.svg)](https://github.com/tekartik/idb_sqflite/actions/workflows/run_ci_flutter.yml)

The IndexedDB API of [idb_shim](https://pub.dev/packages/idb_shim) stored in SQLite through
[sqflite](https://pub.dev/packages/sqflite), for Flutter (Android, iOS, macOS, Windows, Linux) and
Dart VM programs. Write the database code once with idb_shim: IndexedDB in the browser, SQLite
everywhere else. The typed [SDB](https://github.com/tekartik/idb_shim.dart/blob/master/idb_shim/doc/sdb.md)
API of idb_shim works on it too.

## Getting started

idb_sqflite only needs a sqflite `DatabaseFactory`, which depends on the platform:

| Platform | Add | sqflite factory |
|---|---|---|
| Flutter Android, iOS, macOS | `flutter pub add idb_sqflite sqflite` | `databaseFactory` from `package:sqflite/sqflite.dart` (set by the plugin) |
| Flutter Windows, Linux | `flutter pub add idb_sqflite sqflite_common_ffi` | `databaseFactoryFfi`, after `sqfliteFfiInit()` |
| Dart VM (command line, server, unit tests) | `dart pub add idb_sqflite sqflite_common_ffi` | `databaseFactoryFfi`, after `sqfliteFfiInit()` |
| Web | not this package | `idbFactoryNative` from `idb_shim` (the browser IndexedDB) |

`sqflite_common_ffi` bundles SQLite (since 2.4.0): nothing to install on Linux or Windows.

Build the idb factory once with `getIdbFactorySqflite(sqfliteFactory)`, then use the idb_shim
API:

```dart
import 'package:idb_sqflite/idb_sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show databaseFactoryFfi, sqfliteFfiInit;

Future<void> main() async {
  sqfliteFfiInit();
  var idbFactory = getIdbFactorySqflite(databaseFactoryFfi);

  // A relative name is a file in the sqflite databases folder.
  var db = await idbFactory.open(
    'my_records.db',
    version: 1,
    onUpgradeNeeded: (VersionChangeEvent event) {
      event.database.createObjectStore('records', autoIncrement: true);
    },
  );

  var txn = db.transaction('records', idbModeReadWrite);
  var key = await txn.objectStore('records').put({'some': 'data'});
  await txn.completed;

  txn = db.transaction('records', idbModeReadOnly);
  print(await txn.objectStore('records').getObject(key)); // {some: data}
  await txn.completed;
  db.close();
}
```

In a Flutter app for Android, iOS and macOS, the factory comes from the sqflite plugin:

```dart
import 'package:idb_sqflite/idb_sqflite.dart';
import 'package:sqflite/sqflite.dart' show databaseFactory;

/// The idb factory of the app, stored in SQLite.
final idbFactory = getIdbFactorySqflite(databaseFactory);
```

Import sqflite with `show` (or a prefix): both packages export a `Database` class.

### SDB

`package:idb_sqflite/sdb_sqflite.dart` adds `sdbFactoryFromSqflite`:

```dart
import 'package:idb_sqflite/sdb_sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show databaseFactoryFfi, sqfliteFfiInit;

final notes = SdbStoreRef<int, SdbModel>('notes');

Future<void> main() async {
  sqfliteFfiInit();
  var sdbFactory = sdbFactoryFromSqflite(databaseFactoryFfi);
  var db = await sdbFactory.openDatabase(
    'notes.db',
    options: SdbOpenDatabaseOptions(
      version: 1,
      schema: SdbDatabaseSchema(stores: [notes.schema(autoIncrement: true)]),
    ),
  );
  var key = await notes.add(db, {'title': 'hello'});
  print((await notes.record(key).get(db))?.value); // {title: hello}
  await db.close();
}
```

## What to use

| You want | Use |
|---|---|
| The IndexedDB API on a given sqflite factory | `getIdbFactorySqflite(sqfliteFactory)` |
| The IndexedDB API on the global sqflite `databaseFactory` | `idbFactorySqflite` (read it after the global factory is set) |
| The SDB API | `sdbFactoryFromSqflite(sqfliteFactory)` or `sdbFactorySqflite` |
| Every database below one folder | `idbFactory.sandbox(path: folder)` (idb_shim) |
| The file of a database | `await idbFactory.getDatabaseFullPath(name)` |
| A private database in memory | the name `inMemoryDatabasePath` (`':memory:'`) |

The API itself (open, versions, stores, indexes, transactions, cursors) is the idb_shim one: see
the [idb_shim README](https://pub.dev/packages/idb_shim).

## One code base with the web

idb_sqflite does not run in the browser. Pick the factory with a conditional export:

```dart
// db_factory.dart
export 'db_factory_io.dart' if (dart.library.js_interop) 'db_factory_web.dart';
```

```dart
// db_factory_io.dart
import 'package:idb_shim/idb_shim.dart';
import 'package:idb_sqflite/idb_client_sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show databaseFactoryFfi, sqfliteFfiInit;

/// SQLite on the Dart VM and desktop.
IdbFactory getIdbFactory() {
  sqfliteFfiInit();
  return getIdbFactorySqflite(databaseFactoryFfi);
}
```

```dart
// db_factory_web.dart
import 'package:idb_shim/idb_shim.dart';

/// The browser IndexedDB.
IdbFactory getIdbFactory() => idbFactoryNative;
```

The rest of the app imports `db_factory.dart` and only sees an `IdbFactory`.

## Pitfalls

* Store and index names become SQL table names, unquoted: use a letter then letters, digits and
  `_` (no `__`). `'my-store'`, `'by-price'` or `'my store'` make `open` fail, so does a store
  name starting with a digit once it has an index.
* Keys are `int`, `String` or, for an array `keyPath`, lists of those. No `double` and no
  `DateTime` key (store a millisecond `int` or an ISO 8601 string).
* Indexed values: `null` and maps are not indexed (like IndexedDB), a `bool` is indexed as the int
  `1` or `0`, a `DateTime`, an `Uint8List` or a list of strings (outside a `multiEntry` index) in an
  indexed field makes the write fail.
* A transaction commits as soon as no request is pending: do not wait for a network call, a timer
  or the user inside it (`TransactionInactiveError` on the next request).
* Each transaction is one sqflite transaction, read-only ones too: the transactions of a database
  run one at a time.
* Close every `Database` of a name before `deleteDatabase(name)`. `getDatabaseNames()` is not
  supported.

More in [doc/limitation.md](https://github.com/tekartik/idb_sqflite/blob/master/idb_sqflite/doc/limitation.md).

## Examples

* [example/main.dart](https://github.com/tekartik/idb_sqflite/blob/master/idb_sqflite/example/main.dart)
  (IndexedDB API) and
  [example/sdb_example.dart](https://github.com/tekartik/idb_sqflite/blob/master/idb_sqflite/example/sdb_example.dart)
  (SDB), on the Dart VM.
* [notepad_idb](https://github.com/alextekartik/flutter_app_example/tree/master/notepad_idb): a
  Flutter notepad on idb_shim, stored in SQLite on mobile and desktop.
