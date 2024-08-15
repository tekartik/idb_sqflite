import 'package:idb_sqflite/src/idb_import.dart';
import 'package:idb_sqflite/src/sqflite_utils.dart';

/// Where clause for a keyPath
class KeyPathWhere {
  /// Where clause for a keyPath
  KeyPathWhere(this.where, this.whereArgs);

  /// Create a where clause for a keyPath
  factory KeyPathWhere.keyEquals(IdbSqfliteKeyPathMixin keyPath, Object key) {
    var where = keyPath.keyColumnNames.map((name) => '$name = ?').join(' AND ');
    var whereArgs = itemOrItemsToList(key)!.cast<Object>();
    return KeyPathWhere(where, whereArgs);
  }

  /// Create a where clause for a primary key
  factory KeyPathWhere.pkEquals(IdbSqfliteKeyPathMixin keyPath, Object key) {
    var where =
        keyPath.primaryKeyColumnNames.map((name) => '$name = ?').join(' AND ');
    var whereArgs = itemOrItemsToList(key)!.cast<Object>();
    return KeyPathWhere(where, whereArgs);
  }

  /// Where clause
  final String where;

  /// Where arguments
  final List<Object> whereArgs;
}

/// Handle keyPath for store and indecies.
mixin IdbSqfliteKeyPathMixin implements IdbSqfliteKeyPath {
  @override
  Object? get primaryKeyPath;
  @override
  Object? get keyPath;

  /// true if keyPath is an array
  bool get isPrimaryCompositeKey => primaryKeyPath is List;

  /// composite primary key count
  int get primaryCompositeKeyCount => (primaryKeyPath as List).length;

  /// true if keyPath is an array
  @override
  bool get isCompositeKey => keyPath is List;

  @override
  int get compositeKeyCount => (keyPath as List).length;

  /// Non composite only
  String get primaryKeyColumn => primaryKeyColumnName;

  /// ['pk'] ok ['pk1', 'pk2'...]
  late final primaryKeyColumnNames = isPrimaryCompositeKey
      ? List.generate(
          primaryCompositeKeyCount, (i) => primaryKeyIndexToKeyName(i))
      : [primaryKeyColumnName];

  /// ['k'] ok ['k1', 'k2'...]
  late final keyColumnNames = isCompositeKey
      ? List.generate(compositeKeyCount, (i) => keyIndexToKeyName(i))
      : [keyColumnName];

  /// Get the primate key value from a row
  Object rowGetPrimaryKeyValue(Map row) {
    if (isPrimaryCompositeKey) {
      return row.getKeyValue(primaryKeyColumnNames)!;
    } else {
      return row.getKeyValue(primaryKeyColumn)!;
    }
  }

  /// Set the primary key value in a row
  void mapSetPrimaryKeyValue(Map row, Object key) {
    if (isPrimaryCompositeKey) {
      return row.setKeyValue(primaryKeyColumnNames, key);
    } else {
      return row.setKeyValue(primaryKeyColumn, key);
    }
  }
}

/// key path mixin
abstract class IdbSqfliteKeyPath {
  /// Primary key path
  Object? get primaryKeyPath;

  /// Key path
  Object? get keyPath;

  /// true if keyPath is an array
  bool get isCompositeKey;

  /// composite key count
  int get compositeKeyCount;
}

/// index key path mixin
mixin IdbSqfliteIndexKeyPathMixin implements IdbSqfliteKeyPath {}

/// store key path mixin
mixin IdbSqfliteStoreKeyPathMixin implements IdbSqfliteKeyPath {}
