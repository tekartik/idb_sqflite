import 'package:idb_shim/idb_client.dart';

/// Database error
class IdbErrorSqflite extends DatabaseError {
  /// Database error
  IdbErrorSqflite(this.errorCode, String message) : super(message);

  /// Error code for missing key
  static final int missingKeyErrorCode = 3;

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

bool _handleError(dynamic e) {
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
