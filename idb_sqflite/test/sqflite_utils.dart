import 'package:flutter_test/flutter_test.dart';
import 'package:idb_sqflite/src/sqflite_utils.dart';

void main() {
  group('sqflite_utils', () {
    test('wrapKeyPath', () {
      expect(wrapKeyPath('test'), 'test');
      expect(wrapKeyPath('my.test'), 'my__test');
    });
  });
}
