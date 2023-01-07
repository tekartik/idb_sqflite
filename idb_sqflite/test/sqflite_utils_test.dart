import 'package:idb_sqflite/src/sqflite_utils.dart';
import 'package:test/test.dart';

void main() {
  group('sqflite_utils', () {
    test('wrapKeyPath', () {
      expect(wrapKeyPath('test'), 'test');
      expect(wrapKeyPath('my.test'), 'my__test');
    });
    test('keyIndexToKeyName', () {
      expect(keyIndexToKeyName(0), 'k1');
      expect(keyIndexToKeyName(1), 'k2');
    });
    test('primaryKeyIndexToKeyName', () {
      expect(primaryKeyIndexToKeyName(0), 'pk1');
      expect(primaryKeyIndexToKeyName(1), 'pk2');
    });
  });
}
