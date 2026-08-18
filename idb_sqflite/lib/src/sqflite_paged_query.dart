// ignore_for_file: implementation_imports

import 'package:idb_shim/idb_client.dart';
import 'package:idb_sqflite/src/sqflite_query.dart';
import 'package:idb_sqflite/src/sqflite_transaction.dart';

export 'package:idb_shim/src/common/common_paged_query.dart'
    show IdbPagedQuerySupport, IdbPagedCursorRow;
export 'package:idb_shim/utils/idb_cursor_utils.dart'
    show IdbCursorRow, IdbKeyCursorRow;

/// Run a select applying the offset and the limit in sql, so that only the
/// wanted rows are read (a cursor would read the whole table and skip the
/// rows in dart).
Future<List<Map<String, Object?>>> sqflitePagedRows({
  required IdbTransactionSqflite? transaction,
  required String sqlTableName,
  required List<String> columns,
  required List<String> keyColumns,
  KeyRange? range,
  String? direction,
  int? offset,
  int? limit,
}) {
  var query = SqfliteSelectQuery(
    columns,
    sqlTableName,
    keyColumns,
    range,
    direction ?? idbDirectionNext,
    limit: limit,
    offset: offset,
  );
  return query.execute(transaction);
}
