@TestOn('vm')
library;

import 'dart:typed_data';

import 'package:idb_sqflite/idb_sqflite.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:test/test.dart';

/// Regression tests of the 1.5.1 fixes, behaving like IndexedDB.
void main() {
  ffi.sqfliteFfiInit();
  var sqfliteFactory = ffi.databaseFactoryFfiNoIsolate;
  var factory = getIdbFactorySqflite(sqfliteFactory);
  late Database db;
  var dbIndex = 0;

  setUpAll(() async {
    await sqfliteFactory.setDatabasesPath(
      join('.dart_tool', 'idb_sqflite', 'test', 'fixes'),
    );
  });

  Future<void> openDb(void Function(Database db) onUpgrade) async {
    var name = 'fixes_${dbIndex++}.db';
    await factory.deleteDatabase(name);
    db = await factory.open(
      name,
      version: 1,
      onUpgradeNeeded: (e) => onUpgrade(e.database),
    );
  }

  /// Runs [action] on store 's', the transaction failing being ignored.
  Future<T> inTxn<T>(
    String mode,
    Future<T> Function(ObjectStore store) action,
  ) async {
    var txn = db.transaction('s', mode);
    try {
      return await action(txn.objectStore('s'));
    } finally {
      try {
        await txn.completed;
      } catch (_) {}
    }
  }

  Future<T> readWrite<T>(Future<T> Function(ObjectStore store) action) =>
      inTxn(idbModeReadWrite, action);

  Future<T> readOnly<T>(Future<T> Function(ObjectStore store) action) =>
      inTxn(idbModeReadOnly, action);

  /// The error of [action], null if none.
  Future<Object?> errorOf(Future<Object?> Function() action) async {
    try {
      await action();
    } catch (e) {
      return e;
    }
    return null;
  }

  Matcher isDataError = isA<DatabaseError>().having(
    (e) => e.message,
    'message',
    startsWith('DataError'),
  );

  /// Reads the cursor entries as 'key:value field v'.
  Future<List<String>> cursorEntries(
    Stream<CursorWithValue> stream, {
    void Function(CursorWithValue cursor)? onEntry,
  }) async {
    var entries = <String>[];
    await stream
        .listen((cursor) {
          entries.add('${cursor.key}:${(cursor.value as Map)['v']}');
          onEntry?.call(cursor);
          cursor.next();
        })
        .asFuture<void>()
        .timeout(const Duration(seconds: 10));
    return entries;
  }

  tearDown(() {
    db.close();
  });

  group('clear', () {
    test('clear also clears the index rows', () async {
      await openDb((db) {
        db.createObjectStore('s').createIndex('i', 'i');
      });
      await readWrite((store) async {
        await store.put({'i': 'a'}, 1);
        await store.put({'i': 'b'}, 2);
      });
      await readWrite((store) => store.clear());
      // The new record reuses the row id of a cleared one.
      await readWrite((store) => store.put({'i': 'z'}, 10));
      await readOnly((store) async {
        var index = store.index('i');
        expect(await index.count(), 1);
        expect(await index.getAllKeys(), [10]);
        expect(await index.getAll(KeyRange.only('a')), isEmpty);
        expect(await index.getKey('a'), isNull);
      });
    });
  });

  test('add an existing array key fails', () async {
    await openDb((db) {
      db.createObjectStore('s', keyPath: ['a', 'b']);
    });
    var error = await errorOf(
      () => readWrite<void>((store) async {
        await store.add({'a': 1, 'b': 1, 'v': 1});
        await store.add({'a': 1, 'b': 1, 'v': 2});
      }),
    );
    expect('$error', contains('ConstraintError'));
    // The transaction is aborted.
    expect(await readOnly((store) => store.count()), 0);

    await readWrite((store) async {
      await store.add({'a': 1, 'b': 1, 'v': 1});
      await store.add({'a': 1, 'b': 2, 'v': 2});
      // put replaces.
      await store.put({'a': 1, 'b': 1, 'v': 3});
    });
    expect(await readOnly((store) => store.getAll()), [
      {'a': 1, 'b': 1, 'v': 3},
      {'a': 1, 'b': 2, 'v': 2},
    ]);
    await readWrite((store) async {
      // [1] is before [1, 1].
      await store.delete(KeyRange.upperBound([1]));
      await store.delete(KeyRange.lowerBound([1, 1, 0]));
    });
    expect(await readOnly((store) => store.getAllKeys()), [
      [1, 1],
    ]);
  });

  test('string keys never match number keys (autoIncrement)', () async {
    await openDb((db) {
      db.createObjectStore('s', autoIncrement: true);
    });
    await readWrite((store) async {
      await store.add({'v': 1});
      await store.add({'v': 2});
    });
    await readWrite((store) async {
      expect(await store.getObject('1'), isNull);
      expect(await store.getKey('1'), isNull);
      expect(await store.count('1'), 0);
      expect(await store.getAllKeys(KeyRange.only('1')), isEmpty);
      // Numbers are before strings in the key order.
      expect(await store.getAllKeys(KeyRange.lowerBound('1')), isEmpty);
      expect(await store.getAllKeys(KeyRange.upperBound('1')), [1, 2]);
      expect(await store.count(KeyRange.bound(1, '0')), 2);
      expect(
        await cursorEntries(store.openCursor(range: KeyRange.lowerBound('1'))),
        isEmpty,
      );
      await store.delete('1');
      await store.delete(KeyRange.lowerBound('1'));
    });
    expect(await readOnly((store) => store.getAllKeys()), [1, 2]);
  });

  group('index cursor update', () {
    test('every multiEntry entry is visited, with the new value', () async {
      await openDb((db) {
        db.createObjectStore('s').createIndex('t', 't', multiEntry: true);
      });
      await readWrite((store) async {
        await store.put({
          't': ['a', 'b', 'c'],
          'v': 0,
        }, 1);
      });
      var entries = await readWrite(
        (store) => cursorEntries(
          store.index('t').openCursor(autoAdvance: false),
          onEntry: (cursor) {
            if (cursor.key == 'a') {
              cursor.update({
                't': ['a', 'b', 'c'],
                'v': 1,
              });
            }
          },
        ),
      );
      expect(entries, ['a:0', 'b:1', 'c:1']);
    });

    test('array primary key', () async {
      await openDb((db) {
        db
            .createObjectStore('s', keyPath: ['p1', 'p2'])
            .createIndex('t', 't', multiEntry: true);
      });
      await readWrite((store) async {
        await store.put({
          'p1': 1,
          'p2': 2,
          't': ['a', 'b'],
          'v': 0,
        });
      });
      var entries = await readWrite(
        (store) => cursorEntries(
          store.index('t').openCursor(autoAdvance: false),
          onEntry: (cursor) {
            if (cursor.key == 'a') {
              cursor.update({
                'p1': 1,
                'p2': 2,
                't': ['a', 'b'],
                'v': 1,
              });
            }
          },
        ),
      );
      expect(entries, ['a:0', 'b:1']);
    });

    test('delete with an array primary key', () async {
      await openDb((db) {
        db
            .createObjectStore('s', keyPath: ['p1', 'p2'])
            .createIndex('t', 't', multiEntry: true);
      });
      await readWrite((store) async {
        await store.put({
          'p1': 1,
          'p2': 2,
          't': ['a', 'b'],
          'v': 0,
        });
      });
      var entries = await readWrite(
        (store) => cursorEntries(
          store.index('t').openCursor(autoAdvance: false),
          onEntry: (cursor) {
            cursor.delete();
          },
        ),
      );
      expect(entries, ['a:0']);
      expect(await readOnly((store) => store.count()), 0);
    });
  });

  test('failed cursor query ends the stream with its error', () async {
    await openDb((db) {
      db.createObjectStore('s').createIndex('i', 'i');
    });
    await readWrite((store) => store.put({'i': 1, 'v': 0}, 1));
    for (var open in <Stream<Object> Function(ObjectStore store)>[
      (store) => store.openCursor(key: [1]),
      (store) => store.openKeyCursor(key: [1]),
      (store) => store.index('i').openCursor(key: [1]),
      (store) =>
          store.index('i').openKeyCursor(range: KeyRange.lowerBound([1])),
    ]) {
      var error = await errorOf(
        () => readOnly(
          (store) => open(store).toList().timeout(const Duration(seconds: 10)),
        ),
      );
      expect(error, isDataError);
    }
  });

  group('array keys', () {
    test('array keys outside an array keyPath fail', () async {
      await openDb((db) {
        db.createObjectStore('s').createIndex('k', 'k');
      });
      await readWrite((store) async {
        await store.put({'k': 1}, 1);
      });
      for (var action in <Future<Object?> Function(ObjectStore store)>[
        (store) => store.put('v', [1, 2]),
        (store) => store.add('v', [1, 2]),
        (store) => store.getObject([1, 2]),
        (store) => store.count([1]),
        (store) => store.getAll(KeyRange.lowerBound([1])),
        (store) => store.put({
          'k': ['a', 'b'],
        }, 2),
        (store) => store.index('k').count([1]),
        (store) => store.index('k').getKey([1]),
        (store) => store.index('k').getAllKeys(KeyRange.only([1])),
      ]) {
        expect(
          await errorOf(() => readWrite((store) => action(store))),
          isDataError,
        );
      }
      expect(await readOnly((store) => store.getAllKeys()), [1]);
    });

    test('binary keys are single keys', () async {
      await openDb((db) {
        db.createObjectStore('s');
      });
      var key = Uint8List.fromList([1, 2]);
      await readWrite((store) async {
        await store.put('one', key);
        await store.put('two', Uint8List.fromList([1, 2]));
        await store.put('three', 3);
      });
      await readOnly((store) async {
        expect(await store.count(), 2);
        expect(await store.getObject(key), 'two');
        // Binaries are after numbers in the key order.
        expect(await store.getAll(KeyRange.lowerBound(4)), ['two']);
      });
      await readWrite((store) => store.delete(key));
      expect(await readOnly((store) => store.getAllKeys()), [3]);
    });

    test('array keyPath bounds of another length', () async {
      await openDb((db) {
        db.createObjectStore('s').createIndex('ab', ['a', 'b']);
      });
      await readWrite((store) async {
        await store.put({'a': 1, 'b': 1}, 1);
        await store.put({'a': 0, 'b': 5}, 2);
        await store.put({'a': 1, 'b': 'x'}, 3);
      });
      await readOnly((store) async {
        var index = store.index('ab');
        // [1] is before [1, 1].
        expect(await index.getAllKeys(KeyRange.lowerBound([1])), [1, 3]);
        expect(await index.getAllKeys(KeyRange.lowerBound([1], true)), [1, 3]);
        expect(await index.getAllKeys(KeyRange.upperBound([1])), [2]);
        // [0, 5] is before [0, 5, 1], [1, 1] after it.
        expect(await index.getAllKeys(KeyRange.upperBound([0, 5, 1])), [2]);
        expect(await index.getAllKeys(KeyRange.lowerBound([0, 5, 1])), [1, 3]);
        expect(await index.getAllKeys(KeyRange.only([1])), isEmpty);
        // Arrays are after numbers and strings.
        expect(await index.count(KeyRange.lowerBound(0)), 3);
        expect(await index.count(KeyRange.upperBound('z')), 0);
        expect(await index.count(1), 0);
        expect(
          await cursorEntries(
            index.openCursor(range: KeyRange.bound([0, 6], [1, 'z'])),
          ),
          ['[1, 1]:null', '[1, x]:null'],
        );
      });
    });

    test('nested arrays in an array key fail', () async {
      await openDb((db) {
        db.createObjectStore('s', keyPath: ['a', 'b']);
      });
      expect(
        await errorOf(
          () => readWrite(
            (store) => store.put({
              'a': 1,
              'b': [2],
            }),
          ),
        ),
        isDataError,
      );
      expect(
        await errorOf(
          () => readOnly(
            (store) => store.getAll([
              1,
              [2],
            ]),
          ),
        ),
        isDataError,
      );
    });
  });

  group('cursor update', () {
    test('in a readonly transaction fails', () async {
      await openDb((db) {
        db.createObjectStore('s');
      });
      await readWrite((store) => store.put({'v': 0}, 1));
      var errors = <Object?>[];
      await readOnly(
        (store) => cursorEntries(
          store.openCursor(autoAdvance: false),
          onEntry: (cursor) {
            errors.add(null);
            cursor
                .update({'v': 1})
                .then(
                  (_) {},
                  onError: (Object e) {
                    errors[0] = e;
                  },
                );
          },
        ),
      );
      await readOnly(
        (store) => cursorEntries(
          store.openCursor(autoAdvance: false),
          onEntry: (cursor) {
            errors.add(null);
            cursor.delete().then(
              (_) {},
              onError: (Object e) {
                errors[1] = e;
              },
            );
          },
        ),
      );
      expect(errors, [
        isA<DatabaseReadOnlyError>(),
        isA<DatabaseReadOnlyError>(),
      ]);
      expect(await readOnly((store) => store.getObject(1)), {'v': 0});
    });

    test('with a different in-line key fails', () async {
      await openDb((db) {
        db.createObjectStore('s', keyPath: 'id');
      });
      await readWrite((store) => store.put({'id': 1, 'v': 0}));
      Object? error;
      await readWrite(
        (store) => cursorEntries(
          store.openCursor(autoAdvance: false),
          onEntry: (cursor) {
            cursor
                .update({'id': 2, 'v': 1})
                .then(
                  (_) {},
                  onError: (Object e) {
                    error = e;
                  },
                );
          },
        ),
      );
      expect(error, isDataError);
      // The same key or no key at all is fine.
      await readWrite(
        (store) => cursorEntries(
          store.openCursor(autoAdvance: false),
          onEntry: (cursor) {
            cursor.update({'id': 1, 'v': 1});
          },
        ),
      );
      expect(await readOnly((store) => store.getAll()), [
        {'id': 1, 'v': 1},
      ]);
    });
  });

  test('getAll count 0 is unlimited', () async {
    await openDb((db) {
      db.createObjectStore('s').createIndex('i', 'i');
    });
    await readWrite((store) async {
      await store.put({'i': 1}, 1);
      await store.put({'i': 2}, 2);
    });
    await readOnly((store) async {
      var index = store.index('i');
      expect(await store.getAll(null, 0), hasLength(2));
      expect(await store.getAllKeys(null, 0), [1, 2]);
      expect(await index.getAll(null, 0), hasLength(2));
      expect(await index.getAllKeys(null, 0), [1, 2]);
      expect(await store.getAllKeys(null, 1), [1]);
      expect(await index.getAllKeys(null, 1), [1]);
    });
  });

  test('map with a single @ key holding a custom type', () async {
    await openDb((db) {
      db.createObjectStore('s');
    });
    var value = <String, Object?>{
      '@x': {
        'date': DateTime.utc(2020),
        'bytes': Uint8List.fromList([1]),
        'list': [
          {'@y': DateTime.utc(2021)},
        ],
      },
    };
    await readWrite((store) async {
      await store.put(value, 1);
      await store.put({'@x': DateTime.utc(2020)}, 2);
    });
    await readOnly((store) async {
      expect(await store.getObject(1), value);
      expect(await store.getObject(2), {'@x': DateTime.utc(2020)});
    });
  });
}
