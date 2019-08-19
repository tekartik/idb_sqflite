import 'dart:async';

import 'package:idb_sqflite/src/sqflite_error.dart';
import 'package:sqflite/sqlite_api.dart' as sqflite;

var debugTransactionWrapper = false; // devWarning(true);

/*
library idb_shim_websql_wrapper;

import 'dart:web_sql' as wql;
import 'dart:web_sql' show SqlResultSet, SqlError;
export 'dart:web_sql' show SqlResultSet, SqlError, SqlResultSetRowList;
import 'dart:html' as html;
import 'dart:async';

class SqlDatabaseFactory {
  SqlDatabase openDatabase(
      String name, String version, String displayName, int estimatedSize,
      [html.DatabaseCallback creationCallback]) {
    wql.SqlDatabase database = html.window.openDatabase(
        name, version, displayName, estimatedSize, creationCallback);
    if (database == null) {
      return null;
    }
    return new SqlDatabase(database, name, version, displayName, estimatedSize);
  }
}

SqlDatabaseFactory _sqlDatabaseFactory;

SqlDatabaseFactory get sqlDatabaseFactory {
  if (_sqlDatabaseFactory == null) {
    _sqlDatabaseFactory = new SqlDatabaseFactory();
  }
  return _sqlDatabaseFactory;
}

class SqlDatabase {
  @deprecated
  static set debug(bool debug) => _DEBUG = debug;

  static bool get DEBUG => _DEBUG;
  static bool _DEBUG = false;
  static int _DEBUG_ID = 0;

  static bool get supported {
    return wql.SqlDatabase.supported;
  }

  int _debugId;

  wql.SqlDatabase _sqlDatabase;
  SqlDatabase(this._sqlDatabase, String _name, String _version,
      String _displayName, int _estimatedSize) {
    //debug = true; // to remove
    if (_DEBUG) {
      _debugId = ++_DEBUG_ID;
      debugLog(
          "openDatabase $_debugId $_displayName(${_name}, $_version, $_estimatedSize)");
    }
  }

  void debugLog(String msg) {
    String timeText = new DateTime.now().toIso8601String().substring(18);
    print("$timeText $_debugId $msg");
  }

  Future<SqlTransaction> transaction() {
    Completer completer = new Completer.sync();
    _sqlDatabase.transaction((txn) {
      if (_DEBUG) {
        debugLog("BEGIN TRANSACTION");
      }
      completer.complete(new SqlTransaction(this, txn));
    });
    return completer.future;
  }
}
*/
class SqfliteTransactionWrapper {
  SqfliteTransactionWrapper(this.sqfliteDatabase) {
    () async {
      try {
        await sqfliteDatabase.transaction((txn) async {
          if (debugTransactionWrapper) {
            _log('Transaction ready');
          }
          _transactionReadyCompleter.complete(txn);
          await _operationsCompleter.future;
        });
        if (debugTransactionWrapper) {
          _log('Transaction complete');
        }
        _completer.complete(this);
      } catch (e, st) {
        if (debugTransactionWrapper) {
          _log('Transaction error $e');
        }
        _completer.completeError(e, st);
      }
    }();
    // Terminate as soon as possible
    asyncCompleteOperationsIfDone();
  }

  final sqflite.Database sqfliteDatabase;
  final _transactionReadyCompleter = Completer<sqflite.Transaction>.sync();
  final _operationsCompleter = Completer<bool>.sync();
  Future<sqflite.Transaction> get sqfliteTransaction =>
      _transactionReadyCompleter.future;
  /*
  SqlDatabase _database;
  var _sqlTxn;
  //wql.SqlTransaction _sqlTxn;
  static List<Object> EMPTY_ARGS = [];
  */

  void commit() {
    if (debugTransactionWrapper) {
      if (_operationCount != null) {
        _log("COMMIT");
      } else {
        _log('End transaction no operation');
      }
    }
  }

  /*

   * ok that's ugly but in js websql transaction failed as soon as we have a future...
   * so to use when no functions are performed
   *
   * needed for cursor with manual advance

  Future ping() {
    return execute("SELECT 0 WHERE 0 = 1");
  }
  */
  final _completer = Completer<SqfliteTransactionWrapper>();

  void asyncCompleteOperationsIfDone() {
    if (_operationCount == 0) {
      Future(completeOperationsIfDone);
    }
  }

  void completeOperationsIfDone() {
    if (_operationCount == 0) {
      completeOperations();
    }
  }

  void completeOperations() {
    // idbDevPrint('completeOperation $_operationCount');
    if (_operationCount != null) {
      commit();
      // This is an extra debug check
      // that sometimes put the mess...
      _operationCount = null;
    }
    if (!_operationsCompleter.isCompleted) {
      _operationsCompleter.complete(true);
    }
  }

  Future<SqfliteTransactionWrapper> get completed async {
    // Wait for ready first
    await sqfliteTransaction;
    // This take care of empty transaction
    asyncCompleteOperationsIfDone();
    return _completer.future;
  }

  int _operationCount = 0;

  Future<T> run<T>(Future<T> Function(sqflite.Transaction) action) async {
    beginOperation();
    try {
      // idbDevPrint('action');
      return await action(await sqfliteTransaction);
    } finally {
      endOperation();
    }
  }

  Future<List<Map<String, dynamic>>> rawQuery(String sql,
          [List<dynamic> arguments]) =>
      run((txn) => txn.rawQuery(sql, arguments));

  void beginOperation() {
    if (_operationCount == null) {
      throw IdbDatabaseErrorSqflite("TransactionInactiveError");
    }
    _operationCount++;
    // idbDevPrint('_beginOperation $_operationCount');
  }

  void endOperation() {
    // idbDevPrint('_endOperation $_operationCount');
    --_operationCount;

    // Make it breath
    asyncCompleteOperationsIfDone();
  }
}

void _log(dynamic message) {
  print('/sqflite_transaction_wrapper $message');
}
