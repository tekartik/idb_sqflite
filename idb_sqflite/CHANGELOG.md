## 1.3.5

* Fix `Sdb.delete` with boundaries, limit, offset and descending.

## 1.3.4

* Requires dart 3.7

## 1.3.3+7

* sdb (Simple db) support.
* add idbFactorySqflite (using default sqflite factory)
* Check whether a database exists before adding it to the global store database

## 1.3.2+1

* cursor utils support

## 1.3.1

* Dart 3 support

## 1.3.0

* Support strict-casts mode
 
## 1.2.0+1

* Add support for store composite keyPath.

## 1.1.1

* Fix #11, stack overflow when dealing with large dataset

## 1.1.0

* Requires dart sdk 2.15

## 1.0.1

* dart 2.14 lints

## 1.0.0

* `nnbd` support, breaking change

## 0.3.2+2

* Add support for `Transaction.abort`

## 0.3.1+1

* Supports `ObjectStore.getAll/getAllKeys` and `Index.getAll/getAllKeys`
* Bump idb_shim dependency to 1.12.1+1

## 0.3.0+1

* No longer depends on flutter, sqflite must be explicitly added as a dependency.
* Add support for `DateTime` and `Uint8List`

## 0.2.0

* deprecate idbFactorySqflite to allow non-flutter support in the future

## 0.1.0+6

* Initial revision
