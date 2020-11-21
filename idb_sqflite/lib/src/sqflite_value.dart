import 'dart:convert';
import 'dart:typed_data';

/// True for null, num, String, bool
bool isBasicTypeOrNull(Object? value) {
  if (value == null) {
    return true;
  } else {
    return isBasicTypeNotNullNull(value);
  }
}

/// True for null, num, String, bool
bool isBasicTypeNotNullNull(Object? value) {
  if (value is num || value is String || value is bool) {
    return true;
  }
  return false;
}

// Look like custom?
bool _looksLikeCustomType(Map map) =>
    (map.length == 1 && (map.keys.first as String).startsWith('@'));

Object? _toSqfliteValue(Object? value) {
  if (isBasicTypeOrNull(value)) {
    return value;
  } else if (value is Map) {
    var map = value;
    if (_looksLikeCustomType(map)) {
      return <String, Object?>{'@': map};
    }
    var clone;
    map.forEach((key, item) {
      var converted = _toSqfliteValue(item);
      if (!identical(converted, item)) {
        clone ??= Map<String, Object?>.from(map);
        clone[key] = converted;
      }
    });
    return clone ?? map;
  } else if (value is Uint8List) {
    return <String, Object?>{'@Uint8List': base64Encode(value)};
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
    return <String, Object?>{'@DateTime': value.toIso8601String()};
  } else {
    throw ArgumentError.value(value);
  }
}

/// Convert a value to a Sqflite compatible value
Object toSqfliteValue(Object value) {
  late Object converted;
  try {
    converted = _toSqfliteValue(value)!;
  } on ArgumentError catch (e) {
    throw ArgumentError.value(e.invalidValue,
        '${e.invalidValue.runtimeType} in $value', 'not supported');
  }

  /// Ensure root is Map<String, Object?> if only Map
  if (converted is Map && !(converted is Map<String, Object?>)) {
    converted = converted.cast<String, Object?>();
  }
  return converted;
}

Object? _fromSqfliteValue(Object? value) {
  if (isBasicTypeOrNull(value)) {
    return value;
  } else if (value is Map) {
    var map = value;
    if (_looksLikeCustomType(map)) {
      var key = map.keys.first as String;
      switch (key) {
        case '@':
          return map.values.first as Object;
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
    Map? clone;
    map.forEach((key, item) {
      var converted = _fromSqfliteValue(item);
      if (!identical(converted, item)) {
        clone ??= Map<String, Object?>.from(map);
        clone![key] = converted;
      }
    });
    return clone ?? map;
  } else if (value is List) {
    var list = value;
    List? clone;
    for (var i = 0; i < list.length; i++) {
      var item = list[i] as Object;
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
Object fromSqfliteValue(Object value) {
  late Object converted;
  try {
    converted = _fromSqfliteValue(value)!;
  } on ArgumentError catch (e) {
    throw ArgumentError.value(e.invalidValue,
        '${e.invalidValue.runtimeType} in $value', 'not supported');
  }

  /// Ensure root is Map<String, Object?> if only Map
  if (converted is Map && !(converted is Map<String, Object?>)) {
    converted = converted.cast<String, Object?>();
  }
  return converted;
}
