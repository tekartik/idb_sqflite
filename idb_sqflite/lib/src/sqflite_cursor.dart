// ignore_for_file: implementation_imports

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/src/common/common_value.dart';
import 'package:idb_sqflite/src/sqflite_index.dart';
import 'package:idb_sqflite/src/sqflite_object_store.dart';
import 'package:idb_sqflite/src/sqflite_query.dart';
import 'package:idb_sqflite/src/sqflite_transaction.dart';
import 'package:idb_sqflite/src/sqflite_utils.dart';
import 'package:idb_sqflite/src/sqflite_value.dart';
import 'package:synchronized/synchronized.dart';

import 'core_imports.dart';

/// Snapshot mixin for sqflite
mixin IdbRecordSnapshotSqfliteMixin {}

/// Snapshot for sqflite
abstract class IdbRecordSnapshotSqflite {
  /// Create a snapshot from a row
  IdbRecordSnapshotSqflite(this.store, this.row);

  /// The store
  final IdbObjectStoreSqflite store;

  /// The row
  final Map<String, Object?> row;

  /// key
  Object get key;

  /// primary key
  Object get primaryKey => store.rowGetPrimaryKeyValue(row);

  /// value
  Object get value => fromSqfliteValue(decodeValue(row[valueColumnName])!);
}

/// Snapshot for sqflite
class IdbStoreRecordSnapshotSqflite extends IdbRecordSnapshotSqflite {
  /// Create a snapshot from a row
  IdbStoreRecordSnapshotSqflite(super.store, super.row);

  @override
  Object get key => primaryKey;
}

/// Snapshot for sqflite
class IdbIndexRecordSnapshotSqflite extends IdbRecordSnapshotSqflite {
  /// Create a snapshot from a row
  IdbIndexRecordSnapshotSqflite(
    IdbObjectStoreSqflite store,
    this.key,
    this._primaryKey,
    Map<String, Object?> row,
  ) : super(store, row);
  Object? _primaryKey;

  @override
  Object get primaryKey => _primaryKey ??= store.rowGetPrimaryKeyValue(row);

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

abstract class _IdbCommonCursorSqfliteBase<T extends Cursor>
    with _IdbCommonCursorSqfliteMixin<T> {}

abstract mixin class _IdbCommonCursorSqfliteMixin<T extends Cursor> {
  late IdbRecordSnapshotSqflite snapshot;
  late _IdbCursorBaseControllerSqflite<T> _ctlr;

  /// Set right away as it could change in the controller before update/delete is done.
  late final int index;

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
    return _ctlr.lock.synchronized(() async {
      value = toSqfliteValue(value);
      var store = _ctlr.store;
      await store.putImpl(value, primaryKey);
      // Index only handle
      if (_ctlr is _IdbIndexCursorCommonControllerSqflite) {
        // Also update all records in the current list...
        var i = index + 1;
        while (i < _ctlr._rows.length) {
          if (_ctlr._rows[i].primaryKey == primaryKey) {
            // We know it is an index cursor
            _ctlr._rows[i] = IdbIndexRecordSnapshotSqflite(
              store,
              _ctlr._rows[i].key,
              primaryKey,
              <String, Object?>{valueColumnName: encodeValue(value)},
            );
            i++;
          }
          i++;
        }
      }
    });
  }

  Future delete() async {
    return _ctlr.lock.synchronized(() async {
      await _ctlr.store.deleteImpl(primaryKey);
      // Index only handle
      if (_ctlr is _IdbIndexCursorCommonControllerSqflite) {
        var i = index + 1;
        while (i < _ctlr._rows.length) {
          if (_ctlr._rows[i].primaryKey == primaryKey) {
            _ctlr._rows.removeAt(i);
          } else {
            i++;
          }
        }
      }
    });
  }

  @override
  String toString() => '$key $primaryKey';
}

class _IdbCursorSqflite extends _IdbCommonCursorSqfliteBase<Cursor>
    implements Cursor {
  _IdbCursorSqflite(
    _IdbKeyCursorBaseControllerSqflite ctlr,
    IdbRecordSnapshotSqflite snapshot,
  ) {
    this.snapshot = snapshot;
    _ctlr = ctlr;
    index = ctlr.currentIndex!;
  }
}

///
class _IdbCursorWithValueSqflite
    extends _IdbCommonCursorSqfliteBase<CursorWithValue>
    implements CursorWithValue {
  _IdbCursorWithValueSqflite(
    _IdbCursorWithValueBaseControllerSqflite ctlr,
    IdbRecordSnapshotSqflite snapshot,
  ) {
    this.snapshot = snapshot;
    _ctlr = ctlr;
    index = ctlr.currentIndex!;
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
      'Invalid keyRange $key as key argument, use the range argument',
    );
  }
}

abstract class _IdbCursorBaseControllerSqflite<T extends Cursor>
    implements _IdbControllerSqflite {
  _IdbCursorBaseControllerSqflite(this.direction, this.autoAdvance);

  final lock = Lock();
  String direction;
  bool autoAdvance;

  @override
  int? currentIndex;
  @override
  late List<IdbRecordSnapshotSqflite> _rows;

  IdbTransactionSqflite get transaction => store.transaction;

  IdbObjectStoreSqflite get store;

  List<String> get keyColumnNames;

  T newCursor(int index);

  // Sync must be true
  final _ctlr = StreamController<T>(sync: true);

  bool indexIsValid(int index) {
    var length = _rows.length;

    return (index >= 0) && (index < length);
  }

  /// false if it faield
  bool advance(int count) {
    var index = currentIndex = currentIndex! + count;
    var valid = indexIsValid(index);
    lock.synchronized(() {
      var valid = indexIsValid(index);
      if (!valid) {
        // Prevent auto advance
        autoAdvance = false;

        // Make sure the last action is done
        lock.synchronized(() {
          _ctlr.close();
        });
        return false;
      } else {
        _ctlr.add(newCursor(index));
        // return new Future.value();
        return true;
      }
    });
    return valid;
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
  Cursor newCursor(int index) => _IdbCursorSqflite(this, _rows[index]);
}

abstract class _IdbCursorWithValueBaseControllerSqflite
    extends _IdbCursorBaseControllerSqflite<CursorWithValue> {
  _IdbCursorWithValueBaseControllerSqflite(super.direction, super.autoAdvance);

  @override
  CursorWithValue newCursor(int index) =>
      _IdbCursorWithValueSqflite(this, _rows[index]);
}

/// Cursor controller
class IdbCursorWithValueControllerSqflite
    extends _IdbCursorWithValueBaseControllerSqflite
    with
        _IdbCursorCommonControllerSqflite,
        _IdbCursorWithValueCommonControllerSqflite,
        IdbStoreCursorCommonControllerSqflite {
  /// Cursor controller
  IdbCursorWithValueControllerSqflite(
    this.store,
    String direction,
    bool autoAdvance,
  ) //
  : super(direction, autoAdvance);
  @override
  IdbObjectStoreSqflite store;

  /// primaryKeyColumnNames
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

/// Cursor controller
mixin IdbStoreCursorCommonControllerSqflite
    on
        // ignore: library_private_types_in_public_api
        _IdbCursorCommonControllerSqflite {
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
    _rows =
        rows
            .map(
              (row) => IdbIndexRecordSnapshotSqflite(
                store,
                index.isCompositeKey
                    ? _keyValue(row, keyColumnNames)
                    : _keyValue(row, keyColumnName),
                null,
                row,
              ),
            )
            .toList();
    _autoNext();
  }
}

/// Cursor controller
class IdbIndexKeyCursorControllerSqflite
    extends _IdbKeyCursorBaseControllerSqflite
    with
        _IdbCursorCommonControllerSqflite,
        _IdbIndexCursorCommonControllerSqflite {
  /// Cursor controller
  IdbIndexKeyCursorControllerSqflite(
    IdbIndexSqflite index,
    String direction,
    bool autoAdvance,
  ) //
  : super(direction, autoAdvance) {
    this.index = index;
  }

  @override
  List<String> get columns => [...keyColumnNames, ...primaryKeyColumnNames];
}

/// Cursor controller
class IdbKeyCursorControllerSqflite extends _IdbKeyCursorBaseControllerSqflite
    with
        _IdbCursorCommonControllerSqflite,
        _IdbCursorCommonControllerSqflite,
        IdbStoreCursorCommonControllerSqflite {
  /// Cursor controller
  IdbKeyCursorControllerSqflite(
    this.store,
    String direction,
    bool autoAdvance,
  ) //
  : super(direction, autoAdvance);
  @override
  IdbObjectStoreSqflite store;

  @override
  List<String> get columns => store.primaryKeyColumnNames;
}

/// Cursor controller
class IdbIndexCursorWithValueControllerSqflite
    extends _IdbCursorWithValueBaseControllerSqflite
    with
        _IdbCursorCommonControllerSqflite,
        _IdbCursorWithValueCommonControllerSqflite,
        _IdbIndexCursorCommonControllerSqflite {
  /// Cursor controller
  IdbIndexCursorWithValueControllerSqflite(
    IdbIndexSqflite index,
    String direction,
    bool autoAdvance,
  ) //
  : super(direction, autoAdvance) {
    this.index = index;
  }

  @override
  List<String> get columns => [
    ...keyColumnNames,
    ...primaryKeyColumnNames,
    valueColumnName,
  ];
}
