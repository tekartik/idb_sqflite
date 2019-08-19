import 'package:idb_shim/idb_client.dart';

class IdbErrorSqflite extends DatabaseError {
  IdbErrorSqflite(this.errorCode, String message) : super(message);

  static final int missingKeyErrorCode = 3;

  int errorCode;

  @override
  String toString() {
    String text = "IdbErrorSqflite($errorCode)";
    if (message != null) {
      text += ": $message";
    }
    return text;
  }
}

class IdbDatabaseErrorSqflite extends DatabaseError {
  IdbDatabaseErrorSqflite(this._nativeError) : super(null);

  dynamic _nativeError;

  @override
  String get message {
    return _nativeError.toString();
  }
}
/*
part of idb_shim_websql;

class _IdbWebSqlError extends DatabaseError {
  int errorCode;

  static final int MISSING_KEY = 3;

  _IdbWebSqlError(this.errorCode, String message) : super(message);

  String toString() {
    String text = "IdbWebSqlError(${errorCode})";
    if (message != null) {
      text += ": $message";
    }
    return text;
  }
}

class _WebSqlDatabaseError extends DatabaseError {
  dynamic _nativeError;

  int get code {
    if (_nativeError is SqlError) {
      return _nativeError.code;
    }
    return 0;
  }

  _WebSqlDatabaseError(this._nativeError) : super(null);

  String get message {
    if (_nativeError is SqlError) {
      return _nativeError.message;
    }
    return _nativeError.toString();
  }
}
*/
