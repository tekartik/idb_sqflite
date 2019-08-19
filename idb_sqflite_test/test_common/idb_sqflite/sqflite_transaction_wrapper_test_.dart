import 'package:dev_test/test.dart';
import 'package:idb_sqflite/src/sqflite_transaction_wrapper.dart';
import 'package:sqflite/sqlite_api.dart' as sqflite;

defineTests(sqflite.DatabaseFactory factory) {
  sqflite.Database db;
  setUp(() async {
    var path = 'transaction_wrapper.db';
    await factory.deleteDatabase(path);
    db = await factory.openDatabase(path);
  });

  tearDown(() async {
    await db?.close();
  });
  test('transaction', () async {
    var wrapper = SqfliteTransactionWrapper(db);
    await wrapper.completed;
  });

  test('query', () async {
    var txn = SqfliteTransactionWrapper(db);
    var list = await txn.rawQuery('SELECT 0 WHERE 0 = 1');
    expect(list, isEmpty);
    await txn.completed;
  });
  test('two_actions', () async {
    var txn = SqfliteTransactionWrapper(db);
    var list = await txn.rawQuery('SELECT 0 WHERE 0 = 1');
    expect(list, isEmpty);
    list = await txn.rawQuery('SELECT 0 WHERE 0 = 1');
    expect(list, isEmpty);
    await txn.completed;
  });
}

/*
main() {
  if (SqlDatabase.supported) {
    group('wrapper', () {
      //wrapped.sqlDatabaseFactory.o
      test('open', () {
        SqlDatabase db = sqlDatabaseFactory.openDatabase(
            "com.tekartik.test", "1", "com.tekartik.test", 1024 * 1024);
        expect(db, isNotNull);
        //wrapped.SqlTransaction transaction = db.transaction();
      });

      test('transaction', () {
        SqlDatabase db = sqlDatabaseFactory.openDatabase(
            "com.tekartik.test", "1", "com.tekartik.test", 1024 * 1024);
        return db.transaction().then((SqlTransaction transaction) {
          transaction.execute("DROP TABLE IF EXISTS test");
          return transaction.completed;
        });
      });

      test('select 1', () {
        SqlDatabase db = sqlDatabaseFactory.openDatabase(
            "com.tekartik.test", "1", "com.tekartik.test", 1024 * 1024);
        return db.transaction().then((SqlTransaction transaction) {
          transaction.execute("SELECT 0 WHERE 0 = 1").then((rs) {
            expect(rs.rows.length, 0);
            return transaction.completed;
          });
        });
      });

      test('transaction 2 actions', () {
        SqlDatabase db = sqlDatabaseFactory.openDatabase(
            "com.tekartik.test", "1", "com.tekartik.test", 1024 * 1024);
        return db.transaction().then((SqlTransaction transaction) {
          return transaction.execute("DROP TABLE IF EXISTS test").then((_) {
            return transaction
                .execute("CREATE TABLE test (name TEXT)")
                .then((_) {
              return transaction.completed;
            });
          });
        });
      });
    });
  }
}
*/
