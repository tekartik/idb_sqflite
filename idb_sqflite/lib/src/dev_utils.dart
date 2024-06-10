/// Development helpers to generate warning in code
bool _devPrintEnabled = true;

@Deprecated('Dev only')
set devPrintEnabled(bool enabled) => _devPrintEnabled = enabled;

@Deprecated('Dev only')
void devPrint(Object object) {
  if (_devPrintEnabled) {
    // ignore: avoid_print
    print(object);
  }
}

/// Deprecated to prevent keeping the code used.
///
/// Can be use as a todo for weird code. int value = devWarning(myFunction());
/// The function is always called
@Deprecated('Dev only')
T devWarning<T>(T value) => value;

void _devError([Object? msg]) {
  // one day remove the print however sometimes the error thrown is hidden
  try {
    throw UnsupportedError(msg?.toString() ?? 'error');
  } catch (e, st) {
    if (_devPrintEnabled) {
      // ignore: avoid_print
      print('# ERROR $msg');
      // ignore: avoid_print
      print(st);
    }
    rethrow;
  }
}

@Deprecated('Dev only')
void devError([String? msg]) => _devError(msg);
