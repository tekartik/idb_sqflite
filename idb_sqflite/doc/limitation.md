# idb_sqflite limitations

What differs from IndexedDB in a browser (and from the idb_shim sembast backend). The API is the
idb_shim one.

## Names

Store and index names are used unquoted in SQL: the store table is `s__<store>`, an index table
`<store>__<index>`.

* Use a letter then letters, digits and `_`. A dash, a space or a dot (`'my-store'`,
  `'by-price'`) makes `open` fail with an SQLite syntax error, so does a store name starting with
  a digit once it has an index (`2024__i`).
* Avoid `__` in names: store `a` with index `b__c` and store `a__b` with index `c` share the table
  `a__b__c`.

Field names (key paths) are not SQL names, any field name works.

## Keys

* `int` and `String` keys, and for an array `keyPath` (`keyPath: ['a', 'b']`) lists of those.
* `double` keys are not supported (`supportsDoubleKey` is `false`), nor `DateTime` keys: store a
  millisecond `int` or an ISO 8601 string.
* A list is not a key outside an array `keyPath`: `getObject([1, 2])` on a store whose key path is
  not an array throws a `DataError`.

## Indexed values

IndexedDB does not index a value that is not a valid key, idb_sqflite:

* does not index `null` and maps (the record is written, not indexed),
* indexes a `bool` as the int `1` (`true`) or `0` (`false`): `index.get(1)` finds `true`,
* fails the write for a `DateTime`, an `Uint8List` or a list of strings in the field of an index
  that is not `multiEntry`.

A `multiEntry` index with an array `keyPath` is not supported (`createIndex` throws).

## Values

The values are stored as JSON: `null`, `bool`, `num`, `String`, `List`, `Map` with `String` keys,
`DateTime` (read back in UTC) and `Uint8List`, at any depth. Anything else (a custom class, a
`Set`, a `Duration`) makes the write throw an `ArgumentError`.

## Transactions and cursors

* Each transaction is one sqflite transaction, read-only ones too: the transactions of a database
  run one at a time.
* A transaction commits when no request is pending once the current event is done, like
  IndexedDB.
* A cursor reads every row of its range when it opens and walks that list: the whole range is in
  memory, and a change made in the transaction during the walk (other than through the cursor)
  is not seen.

## Databases

* `getDatabaseNames()` throws `UnsupportedError`.
* Opening with a version lower than the stored one throws a `StateError` (`cannot downgrade`); use
  `openOnDowngradeDelete` (idb_shim) to start again instead.
* Close every `Database` of a name before `deleteDatabase(name)`.
