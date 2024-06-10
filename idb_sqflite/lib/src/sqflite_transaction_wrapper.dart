import 'dart:async';

import 'package:idb_sqflite/src/idb_import.dart';
import 'package:idb_sqflite/src/sqflite_error.dart';
import 'package:sqflite_common/sqlite_api.dart' as sqflite;

var debugTransactionWrapper = false; // devWarning(true);

class SqfliteTransactionWrapper {
  SqfliteTransactionWrapper(this.sqfliteDatabase) {
    () async {
      try {
        await sqfliteDatabase!.transaction((txn) async {
          if (debugTransactionWrapper) {
            _log('Transaction ready');
          }
          _transactionReadyCompleter.complete(txn);
          await _operationsCompleter.future;

          // Cancel the transaction if aborted
          if (completedException != null) {
            throw completedException!;
          }
        });
        if (debugTransactionWrapper) {
          _log('Transaction complete');
        }
        _complete();
      } catch (e, st) {
        if (debugTransactionWrapper) {
          _log('Transaction error $e');
        }
        _completeError(e, st);
      }
    }();
    // Terminate as soon as possible
    asyncCompleteOperationsIfDone();
  }
  void _complete() {
    if (!_completer.isCompleted) {
      _completer.complete(this);
    }
  }

  void _completeError(Object e, [StackTrace? st]) {
    if (!_completer.isCompleted) {
      _completer.completeError(e, st);
    }
  }

  final sqflite.Database? sqfliteDatabase;

  final _transactionReadyCompleter = Completer<sqflite.Transaction>.sync();
  final _operationsCompleter = Completer<bool>.sync();

  Future<sqflite.Transaction> get sqfliteTransaction =>
      _transactionReadyCompleter.future;
  Exception? completedException;

  /*
  SqlDatabase _database;
  var _sqlTxn;
  //wql.SqlTransaction _sqlTxn;
  static List<Object> EMPTY_ARGS = [];
  */

  void commit() {
    if (debugTransactionWrapper) {
      if (_operationCount != null) {
        _log('COMMIT');
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
    return execute('SELECT 0 WHERE 0 = 1');
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

  int? _operationCount = 0;

  Future<T> run<T>(Future<T> Function(sqflite.Transaction) action) async {
    beginOperation();
    try {
      // idbDevPrint('action');
      return await action(await sqfliteTransaction);
    } finally {
      endOperation();
    }
  }

  Future<List<Map<String, Object?>>> rawQuery(String sql,
          [List<dynamic>? arguments]) =>
      run((txn) => txn.rawQuery(sql, arguments as List<Object>?));

  void beginOperation() {
    if (_operationCount == null) {
      throw IdbDatabaseErrorSqflite('TransactionInactiveError');
    }
    _operationCount = _operationCount! + 1;
    // idbDevPrint('_beginOperation $_operationCount');
  }

  void endOperation() {
    // idbDevPrint('_endOperation $_operationCount');
    _operationCount = _operationCount! - 1;

    // Make it breath
    asyncCompleteOperationsIfDone();
  }

  void abort() {
    completedException = newAbortException();
  }
}

void _log(dynamic message) {
  // ignore: avoid_print
  print('/sqflite_transaction_wrapper $message');
}
