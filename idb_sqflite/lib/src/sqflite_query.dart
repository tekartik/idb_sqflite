// ignore_for_file: implementation_imports

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/src/common/common_value.dart';
import 'package:idb_sqflite/src/sqflite_transaction.dart';
import 'package:idb_sqflite/src/sqflite_utils.dart';
import 'package:sqflite/utils/utils.dart';

class SqfliteQuery {
  String sqlStatement;
  List<Object> arguments;
}

const String _sqlCountColumnName = "_COUNT";
const _sqlCount = "COUNT(*) AS $_sqlCountColumnName";

class SqfliteSelectQuery extends SqfliteQuery {
  SqfliteSelectQuery(
    this.columns,
    this._sqlTableName,
    this.keyColumns, //
    this.keyOrKeyRange,
    this._direction,
  );
  List<String> columns;
  String _sqlTableName;
  var keyOrKeyRange;
  String _direction;
  List<String> keyColumns;

  Future<List<Map<String, dynamic>>> execute(
      IdbTransactionSqflite transaction) {
    String order;

    if (_direction != null) {
      switch (_direction) {
        case idbDirectionNext:
          order = "ASC";
          break;
        case idbDirectionPrev:
          order = "DESC";
          break;

        default:
          throw ArgumentError("direction '$_direction' not supported");
      }
    }
    List args = [];
    var sb = StringBuffer();

    if (keyOrKeyRange is KeyRange) {
      KeyRange keyRange = keyOrKeyRange as KeyRange;

      var lowers = valueAsList(keyRange.lower)
          ?.map((key) => encodeKey(key))
          ?.toList(growable: false);
      var uppers = valueAsList(keyRange.upper)
          ?.map((key) => encodeKey(key))
          ?.toList(growable: false);
      assert(lowers == null || lowers.length == keyColumns.length);
      assert(uppers == null || uppers.length == keyColumns.length);

      // lower
      var sbLower = StringBuffer();
      if (lowers != null) {
        for (int i = 0; i < keyColumns.length; i++) {
          var column = keyColumns[i];
          var key = lowers[i];

          // last
          if (i == keyColumns.length - 1) {
            if (keyRange.lowerOpen == true) {
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
        for (int i = 1; i < keyColumns.length; i++) {
          sbLower.write('))');
        }
      }

      // lower first
      var sbUpper = StringBuffer();
      if (uppers != null) {
        for (int i = 0; i < keyColumns.length; i++) {
          var column = keyColumns[i];
          var key = uppers[i];

          // last
          if (i == keyColumns.length - 1) {
            if (keyRange.upperOpen == true) {
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
        for (int i = 1; i < keyColumns.length; i++) {
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

      /*
      for (int i = 0; i < keyColumns.length; i++) {
        var sbWhere = StringBuffer();

        if (keyRange.lower != null) {
          if (keyRange.lowerOpen == true) {
            sqlSelect += " AND $keyColumns > ?";
          } else {
            sqlSelect += " AND $keyColumns >= ?";
          }
          args.add(keyRange.lower);
        }
        if (keyRange.upper != null) {
          if (keyRange.upperOpen == true) {
            sqlSelect += " AND $keyColumns < ?";
          } else {
            sqlSelect += " AND $keyColumns <= ?";
          }
          args.add(keyRange.upper);
        }
      }

       */
    } else if (keyOrKeyRange != null) {
      var keys = valueAsList(keyOrKeyRange);
      assert(keys.length == keyColumns.length);
      sb.write('${keyColumns.map((column) => '$column = ?').join(' AND ')}');
      args.addAll(keys.map((key) => encodeKey(key)));
    } else {
      // Not null needed for index key
      if (keyColumns.isNotEmpty && keyColumns.first != primaryKeyColumnName) {
        sb.write(
            '${keyColumns.map((column) => '$column NOT NULL').join(' AND ')}');
      }
    }

    // order not needed for COUNT(*)
    String orderBy;
    if (order != null) {
      orderBy = keyColumns.map((column) => '$column $order').join(', ');
    }
    //var sqlArgs = [encodeKey(key)];
    return transaction.query(_sqlTableName,
        columns: columns,
        where: sb.isEmpty ? null : sb.toString(),
        whereArgs: args,
        orderBy: orderBy);
  }
}

class SqfliteCountQuery extends SqfliteSelectQuery {
  SqfliteCountQuery(
      String sqlTableName, List<String> keyColumns, keyOrKeyRange) //
      : super(
          [_sqlCount],
          sqlTableName,
          keyColumns,
          keyOrKeyRange,
          null,
        );

  Future<int> count(IdbTransactionSqflite transaction) async {
    var rows = await execute(transaction);
    return firstIntValue(rows);
  }
}
