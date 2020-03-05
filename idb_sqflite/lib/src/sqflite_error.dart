import 'package:idb_shim/idb_client.dart';

class IdbErrorSqflite extends DatabaseError {
  IdbErrorSqflite(this.errorCode, String message) : super(message);

  static final int missingKeyErrorCode = 3;

  int errorCode;

  @override
  String toString() {
    var text = 'IdbErrorSqflite($errorCode)';
    if (message != null) {
      text += ': $message';
    }
    return text;
  }
}

class IdbDatabaseErrorSqflite extends DatabaseError {
  IdbDatabaseErrorSqflite(this._nativeError) : super(null);

  final _nativeError;

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
Future<T> catchAsyncSqfliteError<T>(Future<T> Function() action) async {
  try {
    return await action();
  } catch (e) {
    if (!_handleError(e)) {
      rethrow;
    }
    // We should never get there
    return null;
  }
}
