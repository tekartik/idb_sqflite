import 'package:idb_sqflite/idb_sqflite.dart';

Future main() async {
  // The sqflite base factory

  var factory = idbFactorySqflite;
  // define the store name
  const storeName = 'records';

  // open the database
  var db = await factory.open('my_records.db', version: 1,
      onUpgradeNeeded: (VersionChangeEvent event) {
    var db = event.database;
    // create the store
    db.createObjectStore(storeName, autoIncrement: true);
  });

  // put some data
  var txn = db.transaction(storeName, 'readwrite');
  var store = txn.objectStore(storeName);
  var key = await store.put({'some': 'data'});
  await txn.completed;

  // read some data
  txn = db.transaction(storeName, 'readonly');
  store = txn.objectStore(storeName);
  var value = await store.getObject(key);

  print(value);
  await txn.completed;
}
