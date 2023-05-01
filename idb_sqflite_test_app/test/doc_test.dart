import 'package:flutter_test/flutter_test.dart';
import 'package:idb_sqflite/idb_sqflite.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  test('flutter', () {
    // Flutter default factory
    var idbFactorySqflite = getIdbFactorySqflite(databaseFactorySqflitePlugin);

    expect(idbFactorySqflite, isNotNull);
  });
}
