// ignore_for_file: implementation_imports

import 'dart:async';

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/src/common/common_value.dart';
import 'package:idb_sqflite/src/sqflite_index.dart';
import 'package:idb_sqflite/src/sqflite_object_store.dart';
import 'package:idb_sqflite/src/sqflite_query.dart';
import 'package:idb_sqflite/src/sqflite_transaction.dart';
import 'package:idb_sqflite/src/sqflite_utils.dart';

abstract class IdbRecordSnapshotSqflite {
  IdbRecordSnapshotSqflite(this.row);
  final Map<String, dynamic> row;

  dynamic get key;
  dynamic get primaryKey => decodeKey(row[primaryKeyColumnName]);

  dynamic get value => decodeValue(row[valueColumnName]);
}

class IdbStoreRecordSnapshotSqflite extends IdbRecordSnapshotSqflite {
  IdbStoreRecordSnapshotSqflite(Map<String, dynamic> row) : super(row);

  @override
  dynamic get key => primaryKey;
}

class IdbIndexRecordSnapshotSqflite extends IdbRecordSnapshotSqflite {
  IdbIndexRecordSnapshotSqflite(
      this.key, this._primaryKey, Map<String, dynamic> row)
      : super(row);
  final dynamic _primaryKey;
  @override
  dynamic get primaryKey => _primaryKey ?? decodeKey(row[primaryKeyColumnName]);

  @override
  final dynamic key;
}

dynamic _keyValue(Map<String, dynamic> map, dynamic columnOrColumns) {
  if (columnOrColumns is Iterable) {
    var list = <dynamic>[];
    for (var column in columnOrColumns) {
      list.add(decodeKey(map[column as String]));
    }
    return list;
  } else {
    return decodeKey(map[columnOrColumns]);
  }
}

abstract class _IdbCommonCursorSqflite<T extends Cursor> {
  IdbRecordSnapshotSqflite snapshot;
  _IdbCursorBaseControllerSqflite<T> _ctlr;

  List<String> get keyColumnNames => _ctlr.keyColumnNames;

  dynamic get key => snapshot.key;

  dynamic get primaryKey => snapshot.primaryKey;

  String get direction => _ctlr.direction;

  void advance(int count) {
    _ctlr.advance(count);
  }

  void next([Object key]) {
    if (key != null) {
      throw UnimplementedError();
    }
    advance(1);
  }

  Future update(value) async {
    await _ctlr.store.putImpl(value, primaryKey);
    // Index only handle
    if (_ctlr is _IdbIndexCursorCommonControllerSqflite) {
      // Also update all records in the current list...
      var i = _ctlr.currentIndex + 1;
      while (i < _ctlr._rows.length) {
        if (_ctlr._rows[i].primaryKey == primaryKey) {
          // We know it is an index cursor
          _ctlr._rows[i] = IdbIndexRecordSnapshotSqflite(
              _ctlr._rows[i].key,
              primaryKey,
              <String, dynamic>{valueColumnName: encodeValue(value)});
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
      var i = _ctlr.currentIndex + 1;
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

abstract class _IdbCursorBaseControllerSqflite<T extends Cursor>
    implements _IdbControllerSqflite {
  _IdbCursorBaseControllerSqflite(this.direction, this.autoAdvance) {
    if (direction == null) {
      direction = idbDirectionNext;
    }
    if (autoAdvance == null) {
      autoAdvance = false;
    }
  }

  String direction;
  bool autoAdvance;

  @override
  int currentIndex;
  @override
  List<IdbRecordSnapshotSqflite> _rows;

  IdbTransactionSqflite get transaction => store.transaction;

  IdbObjectStoreSqflite get store;

  List<String> get keyColumnNames;

  T get newCursor;

  // Sync must be true
  StreamController<T> _ctlr = StreamController(sync: true);

  bool get currentIndexValid {
    int length = _rows.length;

    return (currentIndex >= 0) && (currentIndex < length);
  }

  /// false if it faield
  bool advance(int count) {
    //int length = rows.length;
    currentIndex += count;
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
        _autoNext();
      }
    }
  }

  Stream<T> get stream => _ctlr.stream;

  /// Set the result from query, this will trigger the controller
  set rows(List<Map<String, dynamic>> rows);
}

abstract class _IdbKeyCursorBaseControllerSqflite
    extends _IdbCursorBaseControllerSqflite<Cursor> {
  _IdbKeyCursorBaseControllerSqflite(String direction, bool autoAdvance)
      : super(direction, autoAdvance);

  @override
  Cursor get newCursor => _IdbCursorSqflite(this, _rows[currentIndex]);
}

abstract class _IdbCursorWithValueBaseControllerSqflite
    extends _IdbCursorBaseControllerSqflite<CursorWithValue> {
  _IdbCursorWithValueBaseControllerSqflite(String direction, bool autoAdvance)
      : super(direction, autoAdvance);

  @override
  CursorWithValue get newCursor =>
      _IdbCursorWithValueSqflite(this, _rows[currentIndex]);
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
  @override
  List<String> get columns => [primaryKeyColumnName, valueColumnName];
}

mixin _IdbCursorWithValueCommonControllerSqflite
    on _IdbCursorCommonControllerSqflite {
  @override
  String get sqlTableName => store.sqlTableName;
}

abstract class _IdbControllerSqflite {
  int get currentIndex;
  set currentIndex(int currentIndex);
  List<IdbRecordSnapshotSqflite> get _rows;
  set _rows(List<IdbRecordSnapshotSqflite> _rows);
  void _autoNext();
}

mixin _IdbCursorCommonControllerSqflite on _IdbControllerSqflite {
  String get direction;

  IdbTransactionSqflite get transaction;

  set rows(List<Map<String, dynamic>> rows);

  // to override
  List<String> get columns;

  /// The list of key [pk
  List<String> get keyColumnNames;

  IdbObjectStoreSqflite get store;

  String get sqlTableName;

  Future execute(key, KeyRange keyRange) {
    var keyOrKeyRange;
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
    on _IdbCursorCommonControllerSqflite {
  @override
  String get sqlTableName => store.sqlTableName;

  @override
  List<String> get keyColumnNames => [primaryKeyColumnName];

  @override
  set rows(List<Map<String, dynamic>> rows) {
    currentIndex = -1;
    _rows = rows.map((row) => IdbStoreRecordSnapshotSqflite(row)).toList();
    _autoNext();
  }
}

mixin _IdbIndexCursorCommonControllerSqflite
    on _IdbCursorCommonControllerSqflite {
  IdbIndexSqflite index;

  @override
  IdbObjectStoreSqflite get store => index.store;

  @override
  List<String> get keyColumnNames => index.keyColumnNames;

  @override
  String get sqlTableName => index.sqlIndexViewName;

  @override
  set rows(List<Map<String, dynamic>> rows) {
    currentIndex = -1;
    _rows = rows
        .map((row) => IdbIndexRecordSnapshotSqflite(
            index.isMultiKey
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
  List<String> get columns => [...keyColumnNames, primaryKeyColumnName];
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
  List<String> get columns => [primaryKeyColumnName];
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
      [...keyColumnNames, primaryKeyColumnName, valueColumnName];
}
