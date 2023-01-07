import 'package:idb_sqflite/src/idb_import.dart';
import 'package:idb_sqflite/src/sqflite_utils.dart';

class KeyPathWhere {
  KeyPathWhere(this.where, this.whereArgs);

  factory KeyPathWhere.keyEquals(IdbSqfliteKeyPathMixin keyPath, Object key) {
    var where = keyPath.keyColumnNames.map((name) => '$name = ?').join(' AND ');
    var whereArgs = itemOrItemsToList(key)!.cast<Object>();
    return KeyPathWhere(where, whereArgs);
  }

  factory KeyPathWhere.pkEquals(IdbSqfliteKeyPathMixin keyPath, Object key) {
    var where =
        keyPath.primaryKeyColumnNames.map((name) => '$name = ?').join(' AND ');
    var whereArgs = itemOrItemsToList(key)!.cast<Object>();
    return KeyPathWhere(where, whereArgs);
  }

  final String where;
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

  int get primaryCompositeKeyCount => (primaryKeyPath as List).length;

  /// true if keyPath is an array
  @override
  bool get isCompositeKey => keyPath is List;

  @override
  int get compositeKeyCount => (keyPath as List).length;

  /// Non composite only
  String get primaryKeyColumn => primaryKeyColumnName;

  // ['pk'] ok ['pk1', 'pk2'...]
  late final primaryKeyColumnNames = isPrimaryCompositeKey
      ? List.generate(
          primaryCompositeKeyCount, (i) => primaryKeyIndexToKeyName(i))
      : [primaryKeyColumnName];
  // ['k'] ok ['k1', 'k2'...]
  late final keyColumnNames = isCompositeKey
      ? List.generate(compositeKeyCount, (i) => keyIndexToKeyName(i))
      : [keyColumnName];

  Object rowGetPrimaryKeyValue(Map row) {
    if (isPrimaryCompositeKey) {
      return row.getKeyValue(primaryKeyColumnNames)!;
    } else {
      return row.getKeyValue(primaryKeyColumn)!;
    }
  }

  void mapSetPrimaryKeyValue(Map row, Object key) {
    if (isPrimaryCompositeKey) {
      return row.setKeyValue(primaryKeyColumnNames, key);
    } else {
      return row.setKeyValue(primaryKeyColumn, key);
    }
  }
}

abstract class IdbSqfliteKeyPath {
  Object? get primaryKeyPath;
  Object? get keyPath;

  /// true if keyPath is an array
  bool get isCompositeKey;

  int get compositeKeyCount;
}

mixin IdbSqfliteIndexKeyPathMixin implements IdbSqfliteKeyPath {}

mixin IdbSqfliteStoreKeyPathMixin implements IdbSqfliteKeyPath {}
