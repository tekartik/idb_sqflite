// ignore: implementation_imports
import 'package:idb_sqflite/src/sqflite_transaction_wrapper.dart';
import 'package:sqflite_common/sqlite_api.dart' as sqflite;
import 'package:test/test.dart';

/// Define the tests
void defineTests(sqflite.DatabaseFactory factory) {
  late sqflite.Database db;
  setUp(() async {
    var path = 'transaction_wrapper.db';
    await factory.deleteDatabase(path);
    db = await factory.openDatabase(path);
  });

  tearDown(() async {
    await db.close();
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
