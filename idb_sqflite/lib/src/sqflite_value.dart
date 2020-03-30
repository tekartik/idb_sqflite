import 'dart:convert';
import 'dart:typed_data';

/// True for null, num, String, bool
bool isBasicTypeOrNull(dynamic value) {
  if (value == null) {
    return true;
  } else if (value is num || value is String || value is bool) {
    return true;
  }
  return false;
}

// Look like custom?
bool _looksLikeCustomType(Map map) =>
    (map.length == 1 && (map.keys.first as String).startsWith('@'));

dynamic _toSqfliteValue(dynamic value) {
  if (isBasicTypeOrNull(value)) {
    return value;
  } else if (value is Map) {
    var map = value;
    if (_looksLikeCustomType(map)) {
      return <String, dynamic>{'@': map};
    }
    var clone;
    map.forEach((key, item) {
      var converted = _toSqfliteValue(item);
      if (!identical(converted, item)) {
        clone ??= Map<String, dynamic>.from(map);
        clone[key] = converted;
      }
    });
    return clone ?? map;
  } else if (value is Uint8List) {
    return <String, dynamic>{'@Uint8List': base64Encode(value)};
  } else if (value is List) {
    var list = value;
    var clone;
    for (var i = 0; i < list.length; i++) {
      var item = list[i];
      var converted = _toSqfliteValue(item);
      if (!identical(converted, item)) {
        clone ??= List.from(list);
        clone[i] = converted;
      }
    }
    return clone ?? list;
  } else if (value is DateTime) {
    return <String, dynamic>{'@DateTime': value.toIso8601String()};
  } else {
    throw ArgumentError.value(value);
  }
}

/// Convert a value to a Sqflite compatible value
dynamic toSqfliteValue(dynamic value) {
  dynamic converted;
  try {
    converted = _toSqfliteValue(value);
  } on ArgumentError catch (e) {
    throw ArgumentError.value(e.invalidValue,
        '${e.invalidValue.runtimeType} in $value', 'not supported');
  }

  /// Ensure root is Map<String, dynamic> if only Map
  if (converted is Map && !(converted is Map<String, dynamic>)) {
    converted = converted.cast<String, dynamic>();
  }
  return converted;
}

dynamic _fromSqfliteValue(dynamic value) {
  if (isBasicTypeOrNull(value)) {
    return value;
  } else if (value is Map) {
    var map = value;
    if (_looksLikeCustomType(map)) {
      var key = map.keys.first as String;
      switch (key) {
        case '@':
          return map.values.first;
        case '@DateTime':
          {
            try {
              return DateTime.parse(map.values.first as String).toUtc();
            } catch (_) {}
          }
          break;
        case '@Uint8List':
          {
            try {
              return base64Decode(map.values.first as String);
            } catch (_) {}
          }
          break;
      }
    }
    var clone;
    map.forEach((key, item) {
      var converted = _fromSqfliteValue(item);
      if (!identical(converted, item)) {
        clone ??= Map<String, dynamic>.from(map);
        clone[key] = converted;
      }
    });
    return clone ?? map;
  } else if (value is List) {
    var list = value;
    var clone;
    for (var i = 0; i < list.length; i++) {
      var item = list[i];
      var converted = _fromSqfliteValue(item);
      if (!identical(converted, item)) {
        clone ??= List.from(list);
        clone[i] = converted;
      }
    }
    return clone ?? list;
  } else {
    throw ArgumentError.value(value);
  }
}

/// Convert a value from a Sqflite value
dynamic fromSqfliteValue(dynamic value) {
  dynamic converted;
  try {
    converted = _fromSqfliteValue(value);
  } on ArgumentError catch (e) {
    throw ArgumentError.value(e.invalidValue,
        '${e.invalidValue.runtimeType} in $value', 'not supported');
  }

  /// Ensure root is Map<String, dynamic> if only Map
  if (converted is Map && !(converted is Map<String, dynamic>)) {
    converted = converted.cast<String, dynamic>();
  }
  return converted;
}
