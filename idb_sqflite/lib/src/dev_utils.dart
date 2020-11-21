/// Development helpers to generate warning in code
bool _devPrintEnabled = true;

@deprecated
set devPrintEnabled(bool enabled) => _devPrintEnabled = enabled;

@deprecated
void devPrint(Object object) {
  if (_devPrintEnabled) {
    print(object);
  }
}

/// Deprecated to prevent keeping the code used.
///
/// Can be use as a todo for weird code. int value = devWarning(myFunction());
/// The function is always called
@deprecated
T devWarning<T>(T value) => value;

void _devError([Object? msg]) {
  // one day remove the print however sometimes the error thrown is hidden
  try {
    throw UnsupportedError(msg?.toString() ?? 'error');
  } catch (e, st) {
    if (_devPrintEnabled) {
      print('# ERROR $msg');
      print(st);
    }
    rethrow;
  }
}

@deprecated
void devError([String? msg]) => _devError(msg);
