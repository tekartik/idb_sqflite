// ignore_for_file: implementation_imports, unnecessary_string_interpolations

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/src/common/common_value.dart';
import 'package:idb_sqflite/src/sqflite_transaction.dart';
import 'package:idb_sqflite/src/sqflite_utils.dart';
import 'package:sqflite_common/utils/utils.dart';

/// Sql query
class SqfliteQuery {
  /// Sql query
  late String sqlStatement;

  /// Sql arguments
  List<Object>? arguments;
}

const String _sqlCountColumnName = '_COUNT';
const _sqlCount = 'COUNT(*) AS $_sqlCountColumnName';

/// Select query
class SqfliteSelectQuery extends SqfliteQuery {
  /// Select query
  SqfliteSelectQuery(
    this.columns,
    this._sqlTableName,
    this.keyColumns, //
    this.keyOrKeyRange,
    this._direction, {
    this.limit,
  });

  /// Columns
  List<String> columns;
  final String _sqlTableName;

  /// key or key range
  Object? keyOrKeyRange;
  final String? _direction;

  /// key columns
  List<String> keyColumns;

  /// limit
  final int? limit;
  // Build during buildParameters
  String? _orderBy;

  /// Built during buildParameters
  String? sqlWhere;

  /// Built during buildParameters
  List<Object>? sqlWhereArgs;

  /// Build the parameters
  void buildParameters() {
    String? order;

    if (_direction != null) {
      switch (_direction) {
        case idbDirectionNext:
          order = 'ASC';
          break;
        case idbDirectionPrev:
          order = 'DESC';
          break;

        default:
          throw ArgumentError("direction '$_direction' not supported");
      }
    }
    var args = <Object>[];
    var sb = StringBuffer();

    if (keyOrKeyRange is KeyRange) {
      var keyRange = keyOrKeyRange as KeyRange;

      var lowers = valueAsList(
        keyRange.lower,
      )?.map((key) => encodeKey(key as Object)).toList(growable: false);
      var uppers = valueAsList(
        keyRange.upper,
      )?.map((key) => encodeKey(key as Object)).toList(growable: false);
      assert(lowers == null || lowers.length == keyColumns.length);
      assert(uppers == null || uppers.length == keyColumns.length);

      // lower
      var sbLower = StringBuffer();
      if (lowers != null) {
        for (var i = 0; i < keyColumns.length; i++) {
          var column = keyColumns[i];
          var key = lowers[i];

          // last
          if (i == keyColumns.length - 1) {
            if (keyRange.lowerOpen) {
              sbLower.write('$column > ?');
            } else {
              sbLower.write('$column >= ?');
            }
            args.add(key);
          } else {
            sbLower.write('($column > ?) OR ($column = ? AND (');
            args.addAll([key, key]);
          }
        }

        // close parenthesis
        for (var i = 1; i < keyColumns.length; i++) {
          sbLower.write('))');
        }
      }

      // upper
      var sbUpper = StringBuffer();
      if (uppers != null) {
        for (var i = 0; i < keyColumns.length; i++) {
          var column = keyColumns[i];
          var key = uppers[i];

          // last
          if (i == keyColumns.length - 1) {
            if (keyRange.upperOpen) {
              sbUpper.write('$column < ?');
            } else {
              sbUpper.write('$column <= ?');
            }
            args.add(key);
          } else {
            sbUpper.write('($column < ?) OR ($column = ? AND (');
            args.addAll([key, key]);
          }
        }

        // close parenthesis
        for (var i = 1; i < keyColumns.length; i++) {
          sbUpper.write('))');
        }
      }

      if (sbLower.isEmpty) {
        if (sbUpper.isNotEmpty) {
          sb.write(sbUpper.toString());
        }
      } else {
        if (sbUpper.isEmpty) {
          sb.write(sbLower.toString());
        } else {
          sb.write('($sbLower) AND ($sbUpper)');
        }
      }
    } else if (keyOrKeyRange != null) {
      var keys = valueAsList(keyOrKeyRange)!;
      // We're missing some keys, make it false
      if (keys.length != keyColumns.length) {
        sb.write('1 = 0');
      } else {
        sb.write('${keyColumns.map((column) => '$column = ?').join(' AND ')}');
        args.addAll(keys.map((key) => encodeKey(key as Object)));
      }
    } else {
      // Not null needed for index key
      // Not it using pk[1] but using k1, k2...
      if (keyColumns.isNotEmpty &&
          !keyColumns.first.startsWith(primaryKeyColumnName)) {
        sb.write(
          '${keyColumns.map((column) => '$column NOT NULL').join(' AND ')}',
        );
      }
    }

    // order not needed for COUNT(*)
    if (order != null) {
      _orderBy = keyColumns.map((column) => '$column $order').join(', ');
    }
    sqlWhere = sb.isEmpty ? null : sb.toString();
    sqlWhereArgs = args;
  }

  /// Execute the query
  Future<List<Map<String, Object?>>> execute(
    IdbTransactionSqflite? transaction,
  ) {
    buildParameters();

    //var sqlArgs = [encodeKey(key)];
    return transaction!.query(
      _sqlTableName,
      columns: columns,
      where: sqlWhere,
      whereArgs: sqlWhereArgs,
      orderBy: _orderBy,
      limit: limit,
    );
  }
}

/// Count query
class SqfliteCountQuery extends SqfliteSelectQuery {
  /// Count query
  SqfliteCountQuery(
    String sqlTableName,
    List<String> keyColumns,
    Object? keyOrKeyRange,
  ) //
  : super([_sqlCount], sqlTableName, keyColumns, keyOrKeyRange, null);

  /// Count
  Future<int> count(IdbTransactionSqflite? transaction) async {
    var rows = await execute(transaction);
    return firstIntValue(rows)!;
  }
}
