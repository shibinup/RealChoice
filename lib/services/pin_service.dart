import 'package:cloud_functions/cloud_functions.dart';

/// Thin wrapper around the `verifyPin` Firebase Cloud Function.
///
/// All PIN comparison logic lives server-side.  The client only sends the
/// 4-digit PIN and receives a boolean result — the stored PIN value is never
/// transmitted to the app.
class PinService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Calls the `verifyPin` Cloud Function.
  ///
  /// Returns `true` when the PIN is correct.
  /// Throws a [FirebaseFunctionsException] on:
  ///   - wrong PIN             → code: `'unknown'`, check [message]
  ///   - rate-limited          → code: `'resource-exhausted'`
  ///   - unauthenticated user  → code: `'unauthenticated'`
  ///   - inactive admin        → code: `'permission-denied'`
  static Future<bool> verifyPin(String pin) async {
    try {
      final callable = _functions.httpsCallable('verifyPin');
      final result = await callable.call<Map<String, dynamic>>({'pin': pin});
      return result.data['success'] == true;
    } on FirebaseFunctionsException {
      rethrow; // Let the UI layer handle specific error codes.
    }
  }
}
