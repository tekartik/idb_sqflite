import 'package:idb_shim/idb_client.dart';
import 'package:idb_sqflite/src/sqflite_index.dart';
import 'package:idb_sqflite/src/sqflite_object_store.dart';
import 'package:idb_sqflite/src/sqflite_query.dart';
import 'package:idb_sqflite/src/sqflite_transaction.dart';
import 'package:idb_sqflite/src/sqflite_utils.dart';
import 'package:idb_sqflite/src/sqflite_value.dart';
import 'package:synchronized/synchronized.dart';

import 'core_imports.dart';
import 'idb_import.dart';

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

/// Read a key (single or composite) from a result row.
Object rowKeyValue(Map<String, Object?> map, Object? columnOrColumns) {
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

  /// Fails (in the transaction, to keep it alive, mimic Chrome behavior)
  /// with [error].
  Future<void> _fail(Error error) =>
      _ctlr.transaction.run(() async => throw error);

  /// Replaces with [replace] the next rows of the record of this cursor (the
  /// other entries of a multiEntry index cursor), or removes them when
  /// [replace] is null.
  void _updateNextRecordRows(
    IdbRecordSnapshotSqflite Function(IdbRecordSnapshotSqflite row)? replace,
  ) {
    if (_ctlr is! _IdbIndexCursorCommonControllerSqflite) {
      return;
    }
    var rows = _ctlr._rows;
    var i = index + 1;
    while (i < rows.length) {
      var row = rows[i];
      if (sqfliteKeyEquals(row.primaryKey, primaryKey)) {
        if (replace == null) {
          rows.removeAt(i);
          continue;
        }
        rows[i] = replace(row);
      }
      i++;
    }
  }

  Future<void> update(Object value) async {
    var store = _ctlr.store;
    if (store.transaction.meta!.mode != idbModeReadWrite) {
      return _fail(DatabaseReadOnlyError());
    }
    var keyPath = store.keyPath;
    if (keyPath != null && value is Map) {
      var inlineKey = value.getKeyValue(keyPath);
      if (inlineKey != null && !sqfliteKeyEquals(inlineKey, primaryKey)) {
        return _fail(
          DatabaseError(
            'DataError: The effective object store of this cursor uses in-line keys and evaluating the key path of the value parameter results in a different value than the cursor\'s effective key.',
          ),
        );
      }
    }
    value = toSqfliteValue(value);
    // Also update the next rows of the record (index cursor only)
    _updateNextRecordRows(
      (row) => IdbIndexRecordSnapshotSqflite(
        store,
        row.key,
        primaryKey,
        <String, Object?>{valueColumnName: encodeValue(value)},
      ),
    );
    await store.putImpl(value, primaryKey);
  }

  Future delete() async {
    if (_ctlr.transaction.meta!.mode != idbModeReadWrite) {
      return _fail(DatabaseReadOnlyError());
    }
    if (this is! CursorWithValue) {
      await _fail(
        StateError(
          'Cannot call cursor.delete when openKeyCursor is used, try openCursor instead',
        ),
      );
    }
    _updateNextRecordRows(null);
    await _ctlr.store.deleteImpl(primaryKey);
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
void checkOpenCursorArguments(Object? key, KeyRange? range) {
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

  // Old recommendation was: Sync must be true
  // however this blows up the stack
  //
  // 2026-04-23 try false, perfect!
  // so: sync must be false otherwise idb_sqflite
  // will blow up the stack when reading 1000 items
  final _ctlr = StreamController<T>(sync: false);

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

  @override
  void _closeWithError(Object error, StackTrace stackTrace) {
    lock.synchronized(() {
      if (!_ctlr.isClosed) {
        _ctlr.addError(error, stackTrace);
        _ctlr.close();
      }
    });
  }

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

  /// Ends the stream with [error], the cursor query failed.
  void _closeWithError(Object error, StackTrace stackTrace);
}

mixin _IdbCursorCommonControllerSqflite on _IdbControllerSqflite {
  String get direction;

  IdbTransactionSqflite get transaction;

  set rows(List<Map<String, Object?>> rows);

  // to override
  List<String> get columns;

  /// The list of key [pk] or [pk1...]
  List<String> get keyColumnNames;

  /// The primary key columns ordering the rows sharing an index key, null
  /// for a store.
  List<String>? get orderPrimaryKeyColumnNames => null;

  IdbObjectStoreSqflite get store;

  String get sqlTableName;

  /// True when [keyColumnNames] hold the items of an array key path.
  bool get compositeKey;

  /// True when [keyColumnNames] is the INTEGER PRIMARY KEY of an autoIncrement
  /// store.
  bool get integerKeys => false;

  /// Runs the cursor query as a request of the store, a failed query ending
  /// the stream with its error.
  void open(Object? key, KeyRange? keyRange) {
    checkOpenCursorArguments(key, keyRange);
    store
        .checkStore(() => execute(key, keyRange))
        .then<void>((_) {}, onError: _closeWithError);
  }

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
      primaryKeyColumns: orderPrimaryKeyColumnNames,
      compositeKey: compositeKey,
      integerKeys: integerKeys,
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
  bool get compositeKey => store.isPrimaryCompositeKey;

  @override
  bool get integerKeys => store.autoIncrement;

  @override
  set rows(List<Map<String, Object?>> rows) {
    currentIndex = -1;
    _rows = rows
        .map((row) => IdbStoreRecordSnapshotSqflite(store, row))
        .toList();
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

  @override
  bool get compositeKey => index.isCompositeKey;

  List<String> get primaryKeyColumnNames => store.primaryKeyColumnNames;

  @override
  List<String> get orderPrimaryKeyColumnNames => primaryKeyColumnNames;

  @override
  String get sqlTableName => index.sqlIndexViewName;

  @override
  set rows(List<Map<String, Object?>> rows) {
    currentIndex = -1;
    _rows = rows
        .map(
          (row) => IdbIndexRecordSnapshotSqflite(
            store,
            index.isCompositeKey
                ? rowKeyValue(row, keyColumnNames)
                : rowKeyValue(row, keyColumnName),
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
