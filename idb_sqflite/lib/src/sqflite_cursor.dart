// ignore_for_file: implementation_imports

import 'dart:async';

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/src/common/common_value.dart';
import 'package:idb_sqflite/src/sqflite_index.dart';
import 'package:idb_sqflite/src/sqflite_object_store.dart';
import 'package:idb_sqflite/src/sqflite_query.dart';
import 'package:idb_sqflite/src/sqflite_transaction.dart';
import 'package:idb_sqflite/src/sqflite_utils.dart';
import 'package:idb_sqflite/src/sqflite_value.dart';

mixin IdbRecordSnapshotSqfliteMixin {}

abstract class IdbRecordSnapshotSqflite {
  IdbRecordSnapshotSqflite(this.store, this.row);

  final IdbObjectStoreSqflite store;
  final Map<String, Object?> row;

  Object get key;

  Object get primaryKey => store.rowGetPrimaryKeyValue(row);

  Object get value => fromSqfliteValue(decodeValue(row[valueColumnName])!);
}

class IdbStoreRecordSnapshotSqflite extends IdbRecordSnapshotSqflite {
  IdbStoreRecordSnapshotSqflite(super.store, super.row);

  @override
  Object get key => primaryKey;
}

class IdbIndexRecordSnapshotSqflite extends IdbRecordSnapshotSqflite {
  IdbIndexRecordSnapshotSqflite(IdbObjectStoreSqflite store, this.key,
      this._primaryKey, Map<String, Object?> row)
      : super(store, row);
  final Object? _primaryKey;

  @override
  Object get primaryKey => _primaryKey ?? store.rowGetPrimaryKeyValue(row);

  @override
  final Object key;
}

Object _keyValue(Map<String, Object?> map, dynamic columnOrColumns) {
  if (columnOrColumns is Iterable) {
    var list = <dynamic>[];
    for (var column in columnOrColumns) {
      list.add(decodeKey(map[column as String]!));
    }
    return list;
  } else {
    return decodeKey(map[columnOrColumns]!);
  }
}

abstract mixin class _IdbCommonCursorSqflite<T extends Cursor> {
  late IdbRecordSnapshotSqflite snapshot;
  late _IdbCursorBaseControllerSqflite<T> _ctlr;

  List<String> get keyColumnNames => _ctlr.keyColumnNames;

  Object get key => snapshot.key;

  Object get primaryKey => snapshot.primaryKey;

  String get direction => _ctlr.direction;

  void advance(int count) {
    _ctlr.advance(count);
  }

  void next([Object? key]) {
    if (key != null) {
      throw UnimplementedError();
    }
    advance(1);
  }

  Future<void> update(Object value) async {
    value = toSqfliteValue(value);
    var store = _ctlr.store;
    await store.putImpl(value, primaryKey);
    // Index only handle
    if (_ctlr is _IdbIndexCursorCommonControllerSqflite) {
      // Also update all records in the current list...
      var i = _ctlr.currentIndex! + 1;
      while (i < _ctlr._rows.length) {
        if (_ctlr._rows[i].primaryKey == primaryKey) {
          // We know it is an index cursor
          _ctlr._rows[i] = IdbIndexRecordSnapshotSqflite(
              store,
              _ctlr._rows[i].key,
              primaryKey,
              <String, Object?>{valueColumnName: encodeValue(value)});
          i++;
        }
        i++;
      }
    }
  }

  Future delete() async {
    await _ctlr.store.deleteImpl(primaryKey);
    // Index only handle
    if (_ctlr is _IdbIndexCursorCommonControllerSqflite) {
      var i = _ctlr.currentIndex! + 1;
      while (i < _ctlr._rows.length) {
        if (_ctlr._rows[i].primaryKey == primaryKey) {
          _ctlr._rows.removeAt(i);
        } else {
          i++;
        }
      }
    }
  }

  @override
  String toString() => '$key $primaryKey';
}

class _IdbCursorSqflite extends Cursor with _IdbCommonCursorSqflite<Cursor> {
  _IdbCursorSqflite(_IdbKeyCursorBaseControllerSqflite ctlr,
      IdbRecordSnapshotSqflite snapshot) {
    this.snapshot = snapshot;
    _ctlr = ctlr;
  }
}

///
class _IdbCursorWithValueSqflite extends CursorWithValue
    with _IdbCommonCursorSqflite<CursorWithValue> {
  _IdbCursorWithValueSqflite(_IdbCursorWithValueBaseControllerSqflite ctlr,
      IdbRecordSnapshotSqflite snapshot) {
    this.snapshot = snapshot;
    _ctlr = ctlr;
  }

  @override
  Object get value => snapshot.value;

  @override
  String toString() => '$key $primaryKey $value';
}

/// Check open cursor arguments
void checkOpenCursorArguments(dynamic key, KeyRange? range) {
  if (key is KeyRange) {
    throw ArgumentError(
        'Invalid keyRange $key as key argument, use the range argument');
  }
}

abstract class _IdbCursorBaseControllerSqflite<T extends Cursor>
    implements _IdbControllerSqflite {
  _IdbCursorBaseControllerSqflite(this.direction, this.autoAdvance);

  String direction;
  bool autoAdvance;

  @override
  int? currentIndex;
  @override
  late List<IdbRecordSnapshotSqflite> _rows;

  IdbTransactionSqflite get transaction => store.transaction;

  IdbObjectStoreSqflite get store;

  List<String> get keyColumnNames;

  T get newCursor;

  // Sync must be true
  final _ctlr = StreamController<T>(sync: true);

  bool get currentIndexValid {
    var length = _rows.length;

    return (currentIndex! >= 0) && (currentIndex! < length);
  }

  /// false if it faield
  bool advance(int count) {
    //int length = rows.length;
    currentIndex = currentIndex! + count;
    if (!currentIndexValid) {
      // Prevent auto advance
      autoAdvance = false;
      // endOperation();
      // pure async

      _ctlr.close();
      return false;
    } else {
      _ctlr.add(newCursor);
      // return new Future.value();
      return true;
    }
  }

  @override
  void _autoNext() {
    if (advance(1)) {
      if (autoAdvance) {
        // Handle issue #11
        // https://github.com/tekartik/idb_sqflite/issues/11
        // that causes stackoverflow,
        // we use to call _autoNextDirectly here
        scheduleMicrotask(() {
          _autoNext();
        });
      }
    }
  }

  Stream<T> get stream => _ctlr.stream;

  /// Set the result from query, this will trigger the controller
  set rows(List<Map<String, Object?>> rows);
}

abstract class _IdbKeyCursorBaseControllerSqflite
    extends _IdbCursorBaseControllerSqflite<Cursor> {
  _IdbKeyCursorBaseControllerSqflite(super.direction, super.autoAdvance);

  @override
  Cursor get newCursor => _IdbCursorSqflite(this, _rows[currentIndex!]);
}

abstract class _IdbCursorWithValueBaseControllerSqflite
    extends _IdbCursorBaseControllerSqflite<CursorWithValue> {
  _IdbCursorWithValueBaseControllerSqflite(super.direction, super.autoAdvance);

  @override
  CursorWithValue get newCursor =>
      _IdbCursorWithValueSqflite(this, _rows[currentIndex!]);
}

class IdbCursorWithValueControllerSqflite
    extends _IdbCursorWithValueBaseControllerSqflite
    with
        _IdbCursorCommonControllerSqflite,
        _IdbCursorWithValueCommonControllerSqflite,
        IdbStoreCursorCommonControllerSqflite {
  IdbCursorWithValueControllerSqflite(
      this.store, String direction, bool autoAdvance) //
      : super(direction, autoAdvance);
  @override
  IdbObjectStoreSqflite store;

  List<String> get primaryKeyColumnNames => store.primaryKeyColumnNames;

  @override
  List<String> get columns => [...primaryKeyColumnNames, valueColumnName];
}

mixin _IdbCursorWithValueCommonControllerSqflite
    on _IdbCursorCommonControllerSqflite {
  @override
  String get sqlTableName => store.sqlTableName;
}

abstract class _IdbControllerSqflite {
  int? get currentIndex;

  set currentIndex(int? currentIndex);

  set _rows(List<IdbRecordSnapshotSqflite> rows);

  void _autoNext();
}

mixin _IdbCursorCommonControllerSqflite on _IdbControllerSqflite {
  String get direction;

  IdbTransactionSqflite get transaction;

  set rows(List<Map<String, Object?>> rows);

  // to override
  List<String> get columns;

  /// The list of key [pk] or [pk1...]
  List<String> get keyColumnNames;

  IdbObjectStoreSqflite get store;

  String get sqlTableName;

  Future execute(Object? key, KeyRange? keyRange) {
    Object? keyOrKeyRange;
    if (key != null) {
      keyOrKeyRange = key;
    } else if (keyRange != null) {
      keyOrKeyRange = keyRange;
    }
    var query = SqfliteSelectQuery(
      columns,
      sqlTableName,
      keyColumnNames,
      keyOrKeyRange,
      direction,
    );
    return query.execute(transaction).then((rs) {
      rows = rs;
    });
  }
}

mixin IdbStoreCursorCommonControllerSqflite
// ignore: library_private_types_in_public_api
    on _IdbCursorCommonControllerSqflite {
  @override
  String get sqlTableName => store.sqlTableName;

  /// For the store, the key is the primary key
  @override
  List<String> get keyColumnNames => store.primaryKeyColumnNames;

  @override
  set rows(List<Map<String, Object?>> rows) {
    currentIndex = -1;
    _rows =
        rows.map((row) => IdbStoreRecordSnapshotSqflite(store, row)).toList();
    _autoNext();
  }
}

mixin _IdbIndexCursorCommonControllerSqflite
    on _IdbCursorCommonControllerSqflite {
  late IdbIndexSqflite index;

  @override
  IdbObjectStoreSqflite get store => index.store;

  @override
  List<String> get keyColumnNames => index.keyColumnNames;

  List<String> get primaryKeyColumnNames => store.primaryKeyColumnNames;

  @override
  String get sqlTableName => index.sqlIndexViewName;

  @override
  set rows(List<Map<String, Object?>> rows) {
    currentIndex = -1;
    _rows = rows
        .map((row) => IdbIndexRecordSnapshotSqflite(
            store,
            index.isCompositeKey
                ? _keyValue(row, keyColumnNames)
                : _keyValue(row, keyColumnName),
            null,
            row))
        .toList();
    _autoNext();
  }
}

class IdbIndexKeyCursorControllerSqflite
    extends _IdbKeyCursorBaseControllerSqflite
    with
        _IdbCursorCommonControllerSqflite,
        _IdbIndexCursorCommonControllerSqflite {
  IdbIndexKeyCursorControllerSqflite(
      IdbIndexSqflite index, String direction, bool autoAdvance) //
      : super(direction, autoAdvance) {
    this.index = index;
  }

  @override
  List<String> get columns => [...keyColumnNames, ...primaryKeyColumnNames];
}

class IdbKeyCursorControllerSqflite extends _IdbKeyCursorBaseControllerSqflite
    with
        _IdbCursorCommonControllerSqflite,
        _IdbCursorCommonControllerSqflite,
        IdbStoreCursorCommonControllerSqflite {
  IdbKeyCursorControllerSqflite(
      this.store, String direction, bool autoAdvance) //
      : super(direction, autoAdvance);
  @override
  IdbObjectStoreSqflite store;

  @override
  List<String> get columns => store.primaryKeyColumnNames;
}

class IdbIndexCursorWithValueControllerSqflite
    extends _IdbCursorWithValueBaseControllerSqflite
    with
        _IdbCursorCommonControllerSqflite,
        _IdbCursorWithValueCommonControllerSqflite,
        _IdbIndexCursorCommonControllerSqflite {
  IdbIndexCursorWithValueControllerSqflite(
      IdbIndexSqflite index, String direction, bool autoAdvance) //
      : super(direction, autoAdvance) {
    this.index = index;
  }

  @override
  List<String> get columns =>
      [...keyColumnNames, ...primaryKeyColumnNames, valueColumnName];
}
