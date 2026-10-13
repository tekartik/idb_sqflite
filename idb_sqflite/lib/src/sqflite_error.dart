import 'package:idb_shim/idb_client.dart';

/// Database error
class IdbErrorSqflite extends DatabaseError {
  /// Database error
  IdbErrorSqflite(this.errorCode, String message) : super(message);

  /// Error code for missing key
  static const int missingKeyErrorCode = 3;

  /// Error code
  int errorCode;

  @override
  String toString() {
    var text = 'IdbErrorSqflite($errorCode): $message';
    return text;
  }
}

/// Database error
class IdbDatabaseErrorSqflite extends DatabaseError {
  /// Database error
  IdbDatabaseErrorSqflite(this._nativeError) : super('native');

  final Object? _nativeError;

  @override
  String get message {
    return _nativeError.toString();
  }
}

/// DataError for an array key stored in a single column: idb_sqflite only
/// stores the items of an array key path, one per column.
DatabaseError sqfliteArrayKeyError(Object key) => DatabaseError(
  'DataError: idb_sqflite does not support the array key $key outside an array keyPath',
);

/// ConstraintError for a key already in a store.
DatabaseError sqfliteKeyExistsError(Object key) => DatabaseError(
  'ConstraintError: Key $key already exists in the object store.',
);

bool _handleError(Object? e) {
  if (e is DatabaseError) {
    return false;
  } else if (e is DatabaseException) {
    return false;
  } else {
    throw DatabaseError(e.toString());
  }
}

//
// We no longer catch the native exception asynchronously
// as it makes the stack trace lost...
//
/// Catch async sqflite error
Future<T> catchAsyncSqfliteError<T>(Future<T> Function() action) async {
  try {
    return await action();
  } catch (e) {
    _handleError(e);
    rethrow;
  }
}
