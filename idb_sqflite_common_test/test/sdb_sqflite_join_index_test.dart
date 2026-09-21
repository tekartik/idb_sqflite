@TestOn('vm')
library;

import 'package:idb_shim/sdb.dart';
import 'package:idb_sqflite/idb_sqflite.dart';
// ignore: implementation_imports
import 'package:idb_sqflite/src/sqflite_database.dart';
// ignore: implementation_imports
import 'package:idb_sqflite/src/sqflite_join_query.dart';
// ignore: implementation_imports
import 'package:idb_sqflite/src/sqflite_utils.dart';
import 'package:sqflite_common/sqlite_api.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:test/test.dart';

var parentStore = SdbStoreRef<int, SdbModel>('join_parent');
var childStore = SdbStoreRef<int, SdbModel>('join_child');
var childParentIndex = childStore.index<int>('parentId');

/// The index created on the record id column of the `parentId` index table.
const _primaryIdIndexName = 'join_child__parentId__pid_only';

/// Names of the sql indexes of the database.
Future<Set<Object?>> _sqlIndexNames(sqflite.Database db) async {
  var rows = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'index'",
  );
  return rows.map((row) => row['name']).toSet();
}

Future main() async {
  ffi.sqfliteFfiInit();

  var idbFactory = getIdbFactorySqflite(ffi.databaseFactoryFfi);
  var factory = sdbFactoryFromIdb(idbFactory);
  var dbName = 'sdb_sqflite_join_index.db';

  Future<SdbDatabase> open() => factory.openDatabase(
    dbName,
    options: SdbOpenDatabaseOptions(
      version: 1,
      schema: SdbDatabaseSchema(
        stores: [
          parentStore.schema(),
          childStore.schema(
            indexes: [childParentIndex.schema(keyPath: 'parentId')],
          ),
        ],
      ),
    ),
  );

  /// The raw sqflite database behind an open sdb database.
  sqflite.Database rawDb(SdbDatabase db) =>
      (db.rawIdb as IdbDatabaseSqflite).sqlDb!;

  group('sdb_sqflite_join_index', () {
    setUp(() async {
      await factory.deleteDatabase(dbName);
    });

    test('an index table has an index on the record id column', () async {
      var db = await open();
      expect(await _sqlIndexNames(rawDb(db)), contains(_primaryIdIndexName));
      await db.close();
    });

    test('a missing record id index is created on open', () async {
      var db = await open();
      // An index table created before that index existed.
      await rawDb(db).execute('DROP INDEX $_primaryIdIndexName');
      expect(
        await _sqlIndexNames(rawDb(db)),
        isNot(contains(_primaryIdIndexName)),
      );
      await db.close();

      db = await open();
      expect(await _sqlIndexNames(rawDb(db)), contains(_primaryIdIndexName));
      await db.close();
    });

    test('the join reads the key from the index table', () async {
      var db = await open();
      await db.inStoresTransaction(
        [parentStore, childStore],
        SdbTransactionMode.readWrite,
        (txn) async {
          await parentStore.record(1).put(txn, {'label': 'p1'});
          await childStore.record(1).put(txn, {'parentId': 1});
          await childStore.record(2).put(txn, {'parentId': 9});
          await childStore.record(3).put(txn, <String, Object?>{});
        },
      );
      await db.close();

      // Reach the raw idb object store to check which native path is taken.
      var raw = await idbFactory.open(dbName);
      var txn = raw.transaction([
        childStore.name,
        parentStore.name,
      ], idbModeReadOnly);
      var store = txn.objectStore(childStore.name);
      expect(store, isA<IdbJoinQuerySupport>());

      // The generated sql must go through the index table, not json_extract,
      // and must not need the json1 functions at all.
      var database = (raw as IdbDatabaseSqflite);
      expect(
        database.supportsJsonExtract,
        isNull,
        reason: 'json1 must not even be probed when the key path is indexed',
      );

      var rows = await (store as IdbJoinQuerySupport).joinedRowList(
        joinStoreName: parentStore.name,
        joinKeyPath: 'parentId',
      );
      expect(rows, isNotNull, reason: 'the native join must be used');
      expect(rows!.map((row) => row.primaryKey).toList(), [1, 2, 3]);
      expect(rows.map((row) => row.joinKey).toList(), [1, 9, null]);
      expect(rows.map((row) => row.joinedValue).toList(), [
        {'label': 'p1'},
        null,
        null,
      ]);
      expect(database.supportsJsonExtract, isNull);

      await txn.completed;
      raw.close();
    });

    test('an index source reads the join key from the index view', () async {
      var db = await open();
      await db.inStoresTransaction(
        [parentStore, childStore],
        SdbTransactionMode.readWrite,
        (txn) async {
          await parentStore.record(1).put(txn, {'label': 'p1'});
          await childStore.record(1).put(txn, {'parentId': 1});
          await childStore.record(2).put(txn, {'parentId': 1});
          await childStore.record(3).put(txn, {'parentId': 9});
          await childStore.record(4).put(txn, <String, Object?>{});
        },
      );
      await db.close();

      var raw = await idbFactory.open(dbName);
      var txn = raw.transaction([
        childStore.name,
        parentStore.name,
      ], idbModeReadOnly);
      var index = txn.objectStore(childStore.name).index('parentId');
      expect(index, isA<IdbJoinQuerySupport>());

      var rows = await (index as IdbJoinQuerySupport).joinedRowList(
        joinStoreName: parentStore.name,
      );
      expect(rows, isNotNull, reason: 'the native join must be used');
      // Record 4 has no index key, so it is not in the index at all.
      expect(rows!.map((row) => row.primaryKey).toList(), [1, 2, 3]);
      expect(rows.map((row) => row.joinKey).toList(), [1, 1, 9]);
      expect(rows.map((row) => row.joinedPrimaryKey).toList(), [1, 1, null]);
      // json1 is never needed when the key comes from an index.
      expect((raw as IdbDatabaseSqflite).supportsJsonExtract, isNull);

      await txn.completed;
      raw.close();
    });

    test('a one to many join goes through the joined index view', () async {
      var db = await open();
      await db.inStoresTransaction(
        [parentStore, childStore],
        SdbTransactionMode.readWrite,
        (txn) async {
          await parentStore.record(1).put(txn, {'label': 'p1'});
          await parentStore.record(2).put(txn, {'label': 'p2'});
          await childStore.record(1).put(txn, {'parentId': 1});
          await childStore.record(2).put(txn, {'parentId': 1});
        },
      );
      await db.close();

      var raw = await idbFactory.open(dbName);
      var txn = raw.transaction([
        childStore.name,
        parentStore.name,
      ], idbModeReadOnly);
      // Iterating the parents, matching their primary key against the index
      // on the child side.
      var store = txn.objectStore(parentStore.name);
      var rows = await (store as IdbJoinQuerySupport).joinedRowList(
        joinStoreName: childStore.name,
        joinIndexName: 'parentId',
      );
      expect(rows, isNotNull, reason: 'the native join must be used');
      // Parent 1 has two children, so it comes back twice; parent 2 has none.
      expect(rows!.map((row) => row.primaryKey).toList(), [1, 1, 2]);
      expect(rows.map((row) => row.joinedPrimaryKey).toList(), [1, 2, null]);

      await txn.completed;
      raw.close();
    });

    test('the join uses the record id index', () async {
      // A bad plan is still correct, but it makes the join scan the whole
      // index table for every record, so it is worth locking in.
      var db = await open();
      await db.inStoresTransaction(
        [parentStore, childStore],
        SdbTransactionMode.readWrite,
        (txn) async {
          for (var i = 1; i <= 20; i++) {
            await parentStore.record(i).put(txn, {'label': 'p$i'});
          }
          for (var i = 1; i <= 200; i++) {
            await childStore.record(i).put(txn, {'parentId': (i % 20) + 1});
          }
        },
      );
      var sql = rawDb(db);

      /// The plan of the statement the join actually runs.
      Future<List<String>> planOf({required bool inner}) async {
        var statement = sqfliteJoinStatement(
          source: SqfliteJoinSource(
            from: 's__${childStore.name}',
            primaryKeyColumns: [primaryKeyColumnName],
            rangeColumns: [primaryKeyColumnName],
            keySource: SqfliteJoinKeySource.sourceIndex,
            keyColumn: keyColumnName,
            indexTable: '${childStore.name}__parentId',
          ),
          target: SqfliteJoinTarget(
            from: 's__${parentStore.name}',
            keyColumn: primaryKeyColumnName,
            primaryKeyColumn: primaryKeyColumnName,
          ),
          offset: 50,
          limit: 100,
          inner: inner,
        );
        var plan = await sql.rawQuery(
          'EXPLAIN QUERY PLAN ${statement.sql}',
          statement.args,
        );
        return plan.map((row) => row['detail'].toString()).toList();
      }

      /// The plan of an index source join, the shape to prefer.
      Future<List<String>> indexSourcePlan({required bool inner}) async {
        var statement = sqfliteJoinStatement(
          source: SqfliteJoinSource(
            from: '${childStore.name}__parentId__j',
            primaryKeyColumns: [primaryKeyColumnName],
            rangeColumns: [keyColumnName],
            keySource: SqfliteJoinKeySource.ownKey,
            keyColumn: keyColumnName,
          ),
          target: SqfliteJoinTarget(
            from: 's__${parentStore.name}',
            keyColumn: primaryKeyColumnName,
            primaryKeyColumn: primaryKeyColumnName,
          ),
          offset: 50,
          limit: 100,
          inner: inner,
        );
        var plan = await sql.rawQuery(
          'EXPLAIN QUERY PLAN ${statement.sql}',
          statement.args,
        );
        return plan.map((row) => row['detail'].toString()).toList();
      }

      for (var inner in [false, true]) {
        var details = await planOf(inner: inner);
        var reason = 'inner: $inner, got $details';
        expect(
          details.any((detail) => detail.contains(_primaryIdIndexName)),
          isTrue,
          reason: 'the record id index must be used, $reason',
        );
        expect(
          details.any((detail) => detail.startsWith('SCAN _bi')),
          isFalse,
          reason: 'the index table must not be scanned, $reason',
        );
        expect(
          details.any((detail) => detail.contains('TEMP B-TREE')),
          isFalse,
          reason: 'the order must come from the index, $reason',
        );
        expect(
          details.any((detail) => detail.contains('AUTOMATIC')),
          isFalse,
          reason: 'no transient index must be built per query, $reason',
        );

        var indexDetails = await indexSourcePlan(inner: inner);
        var indexReason = 'inner: $inner, got $indexDetails';
        expect(
          // Whichever index of the index table sqlite picks, the index key
          // has to be what gives the order.
          indexDetails.any(
            (detail) => detail.contains('${childStore.name}__parentId__'),
          ),
          isTrue,
          reason: 'the index key must give the order, $indexReason',
        );
        expect(
          indexDetails.any((detail) => detail.contains('TEMP B-TREE')),
          isFalse,
          reason: 'the order must come from the index, $indexReason',
        );
        expect(
          indexDetails.any((detail) => detail.contains('AUTOMATIC')),
          isFalse,
          reason: 'no transient index must be built per query, $indexReason',
        );
        expect(
          indexDetails.any((detail) => detail.startsWith('SCAN s__')),
          isFalse,
          reason: 'no table may be scanned, $indexReason',
        );
      }
      await db.close();
    });
  });
}
