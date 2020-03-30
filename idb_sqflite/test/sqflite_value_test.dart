library idb_shim.sqflite_value_test;

import 'dart:typed_data';

import 'package:idb_sqflite/src/sqflite_value.dart';
import 'package:test/test.dart';

void main() {
  group('Sqflite_value', () {
    test('dateTime', () {
      expect(
          fromSqfliteValue(
              toSqfliteValue(DateTime.fromMillisecondsSinceEpoch(1))),
          DateTime.fromMillisecondsSinceEpoch(1, isUtc: true));
    });
    test('allAdapters', () {
      var decoded = {
        'null': null,
        'bool': true,
        'int': 1,
        'list': [1, 2, 3],
        'map': {
          'sub': [1, 2, 3]
        },
        'string': 'text',
        'dateTime': DateTime.fromMillisecondsSinceEpoch(1, isUtc: true),
        'blob': Uint8List.fromList([1, 2, 3]),
      };
      var encoded = {
        'null': null,
        'bool': true,
        'int': 1,
        'list': [1, 2, 3],
        'map': {
          'sub': [1, 2, 3]
        },
        'string': 'text',
        'dateTime': {'@DateTime': '1970-01-01T00:00:00.001Z'},
        'blob': {'@Uint8List': 'AQID'}
      };
      expect(toSqfliteValue(decoded), encoded);
      expect(fromSqfliteValue(encoded), decoded);
    });

    test('modified', () {
      var identicals = [
        <String, dynamic>{},
        1,
        2.5,
        'text',
        true,
        null,
        //<dynamic, dynamic>{},
        [],
        [
          {
            'test': [
              1,
              true,
              [4.5]
            ]
          }
        ],
        <String, dynamic>{
          'test': [
            1,
            true,
            [4.5]
          ]
        }
      ];
      for (var value in identicals) {
        var encoded = value;
        encoded = toSqfliteValue(value);

        expect(identical(encoded, value), isTrue,
            reason:
                '$value ${identityHashCode(value)} vs ${identityHashCode(encoded)}');
        value = fromSqfliteValue(encoded);
        expect(identical(encoded, value), isTrue,
            reason:
                '$value ${identityHashCode(value)} vs ${identityHashCode(encoded)}');
      }
      var notIdenticals = [
        <dynamic, dynamic>{}, // being cast
        Uint8List.fromList([1, 2, 3]),
        DateTime.fromMillisecondsSinceEpoch(1, isUtc: true),
        [DateTime.fromMillisecondsSinceEpoch(1, isUtc: true)],
        <String, dynamic>{
          'test': DateTime.fromMillisecondsSinceEpoch(1, isUtc: true)
        },
        <String, dynamic>{
          'test': [
            DateTime.fromMillisecondsSinceEpoch(1, isUtc: true),
          ]
        }
      ];
      for (var value in notIdenticals) {
        var encoded = value;
        encoded = toSqfliteValue(value);
        expect(fromSqfliteValue(encoded), value);
        expect(!identical(encoded, value), isTrue,
            reason:
                '$value ${identityHashCode(value)} vs ${identityHashCode(encoded)}');
      }
    });
  });
}
