import 'package:flutter_test/flutter_test.dart';
import 'package:idb_sqflite/idb_sqflite.dart';

void main() {
  test('public', () {
    // ignore: deprecated_member_use_from_same_package
    idbFactorySqflite;
    // ignore: unnecessary_statements
    getIdbFactorySqflite;
  });
}
