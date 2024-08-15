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

/// Returns always a list unless null
List? itemOrItemsToList(Object? itemOrItems) {
  if (itemOrItems == null) {
    return null;
  }
  if (itemOrItems is List) {
    return itemOrItems;
  } else if (itemOrItems is Iterable) {
    return itemOrItems.toList();
  }
  return [itemOrItems];
}
