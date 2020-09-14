# idb_sqflite

Indexed DB for flutter on top of sqflite.

* Supports both iOS and Android
* Supports Flutter Web through idb_shim.
* Supports Dart VM (Desktop) through idb_shim

## Example

Simple notepad available [here](https://github.com/alextekartik/flutter_app_example/tree/master/notepad) running on
Flutter (iOS/Android/Web).

## Getting Started

```dart
import 'package:idb_sqflite/idb_sqflite.dart';
import 'package:sqflite/sqflite.dart';

Future main() async {
  // The sqflite flutter factory
  var factory = getIdbFactorySqflite(databaseFactory);
  // define the store name
  const String storeName = "records";

  // open the database
  Database db = await factory.open("my_records.db", version: 1,
      onUpgradeNeeded: (VersionChangeEvent event) {
    Database db = event.database;
    // create the store
    db.createObjectStore(storeName, autoIncrement: true);
  });

  // put some data
  var txn = db.transaction(storeName, idbModeReadWrite);
  var store = txn.objectStore(storeName);
  var key = await store.put({"some": "data"});
  await txn.completed;

  // read some data
  txn = db.transaction(storeName, idbModeReadOnly);
  store = txn.objectStore(storeName);
  var value = await store.getObject(key);

  print(value);
  await txn.completed;
}
```

See [idb_shim](https://github.com/tekartik/idb_shim.dart) for API usage or more generally the 
[W3C reference](https://www.w3.org/TR/IndexedDB-2/) 

