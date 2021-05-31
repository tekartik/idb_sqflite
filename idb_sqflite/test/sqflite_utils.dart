import 'package:idb_sqflite/src/sqflite_utils.dart';
import 'package:test/test.dart';

void main() {
  group('sqflite_utils', () {
    test('wrapKeyPath', () {
      expect(wrapKeyPath('test'), 'test');
      expect(wrapKeyPath('my.test'), 'my__test');
    });
  });
}
