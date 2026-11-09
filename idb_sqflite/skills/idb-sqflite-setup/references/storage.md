# idb_sqflite SQLite layout

Useful when opening an idb_sqflite database file with a SQLite tool or when
debugging. None of this is a public API; do not write to these tables.

## Database file

* One SQLite file per IndexedDB database, opened through the sqflite
  `DatabaseFactory` with sqflite version `1`, `PRAGMA foreign_keys = ON` and
  `onDowngrade: onDatabaseDowngradeDelete`.
* `__version`: single row, columns `value` (the IndexedDB version, `INT`) and
  `signature` (`'com.tekartik.idb'`). In a file whose signature does not
  match, `__version` and `__stores` are created again (empty) on open.
* `__stores`: one row per object store, columns `name` (`TEXT UNIQUE`) and
  `meta` (`TEXT`, JSON of the store meta: `keyPath`, `autoIncrement`,
  indexes).
* An IndexedDB version upgrade runs `onUpgradeNeeded` inside one sqflite
  transaction; schema changes are applied before each request of the callback
  and at its end, then `__version.value` is updated. An error rolls the whole
  transaction back.

## Object store tables

* Table `s__<storeName>`.
* `autoIncrement: true`: `pk INTEGER PRIMARY KEY AUTOINCREMENT`.
* Single key: `pk BLOB PRIMARY KEY`.
* Composite key path (`keyPath: ['a', 'b']`): columns `pk1 BLOB NOT NULL`,
  `pk2 BLOB NOT NULL`... with an index `s__<store>__pk` on them.
* `v BLOB`: the record value, JSON text produced by `encodeValue` from
  idb_shim after `toSqfliteValue` (see below).
* The inline key (`keyPath`) is not duplicated in `v` when it was generated;
  it is re-inserted into the map on read.

## Index tables

* Table `<storeName>__<indexName>` with `k BLOB` (or `k1 BLOB`, `k2 BLOB`...
  for an array key path) and `pid BLOB` (the store row id).
* View `<storeName>__<indexName>__j` joins the index table with the store
  table (`k*`, `pk*`, `v`) for queries.
* SQL indexes `<storeName>__<indexName>__k` on the key column(s) (`UNIQUE`
  when `unique: true`), `<storeName>__<indexName>__pid` on (keys, `pid`),
  `<storeName>__<indexName>__pid_only` on `pid` and, for an array key path,
  one `<storeName>__<indexName>__k<i>` per column.
* `multiEntry: true` inserts one row per array element; combining it with an
  array key path is not supported.
* A `null` or map index value (or array element) gets no row; a `bool` is
  stored as `1` or `0`.

## Value encoding (`toSqfliteValue` / `fromSqfliteValue`)

Applied recursively before JSON encoding and after decoding:

| Dart value            | Stored JSON                                   |
|-----------------------|-----------------------------------------------|
| `null`, `bool`, `num`, `String` | as is                               |
| `List`                | JSON array (elements converted)               |
| `Map` (String keys)   | JSON object (values converted)                |
| `DateTime`            | `{"@DateTime": "<ISO 8601>"}` read back UTC   |
| `Uint8List`           | `{"@Uint8List": "<base64>"}`                  |
| `Map` with a single key starting with `@` | `{"@": {...}}` (escaped) |
| anything else         | `ArgumentError` (not supported)               |

Keys (`pk`, `k`) are stored as SQLite values directly (`INTEGER`/`TEXT`), so
`int` and `String` keys sort natively; `double` keys are not supported.

## Global store

`com.tekartik.idb.global_store` is an internal sqflite database with a
`database(name)` table, historically used for `getDatabaseNames()`. It is no
longer consulted (`getDatabaseNames()` throws `UnsupportedError`).
