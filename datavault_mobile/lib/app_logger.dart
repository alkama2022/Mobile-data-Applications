import 'package:flutter/foundation.dart';

/// Centralized logging. Debug prints locally, release is silent by default
/// (wire to Crashlytics/Sentry here later — single call-site).
void logError(String message, Object error, [StackTrace? stack]) {
  if (kDebugMode) {
    debugPrint('[ERROR] $message: $error');
    if (stack != null) debugPrint(stack.toString());
  }
}

void logInfo(String message) {
  if (kDebugMode) debugPrint('[INFO] $message');
}

/// Human-friendly error message for snackbars. Strips Dart exception prefixes
/// and never leaks raw stack traces to users.
String friendlyError(Object e) {
  final s = e.toString().replaceFirst('Exception: ', '');
  if (s.length > 160) return '${s.substring(0, 160)}…';
  return s;
}
