import 'dart:typed_data';

/// Wrap a key path
String wrapKeyPath(String keyPath) => keyPath.replaceAll('.', '__');

/// The key column in index
String get keyColumnName => mainKeyColumnName;

/// The key column in index
const mainKeyColumnName = 'k';

/// The value column in store
String get valueColumnName => mainValueColumnName;

/// The value column in store
const mainValueColumnName = 'v';

/// The primary key in the store
const primaryKeyColumnName = 'pk';

/// The record row id column in index (an int)
const primaryIdColumnName = 'pid';

/// key1, key2...
String keyIndexToKeyName(int index) => '$keyColumnName${index + 1}';

/// For composite key.
String primaryKeyIndexToKeyName(int index) =>
    '$primaryKeyColumnName${index + 1}';

/// The row id column in store
const sqliteRowId = 'rowid';

/// True for an array key, a [Uint8List] being a binary key.
bool sqfliteIsArrayKey(Object? key) => key is List && key is! Uint8List;

/// True if the keys [key1] and [key2] are equal, array and binary keys being
/// compared item by item.
bool sqfliteKeyEquals(Object? key1, Object? key2) {
  if (key1 is List && key2 is List) {
    if (key1.length != key2.length) {
      return false;
    }
    for (var i = 0; i < key1.length; i++) {
      if (!sqfliteKeyEquals(key1[i], key2[i])) {
        return false;
      }
    }
    return true;
  }
  return key1 == key2;
}
