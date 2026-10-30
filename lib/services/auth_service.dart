///import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _isLoggedInKey = 'is_logged_in';

  /// The shop PIN that must be entered on both login and the PIN page.
  static const String predefinedPin = '1234';

  /// Returns true if the user has a saved logged-in session.
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  /// Signs in with Firebase, then persists the session flag.
  /// Throws [FirebaseAuthException] on auth failure.
  static Future<void> login(String email, String password, String pin) async {
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, true);
  }

  /// Signs out of Firebase and clears the local session flag.
  static Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_isLoggedInKey);
  }

  /// Returns true when [pin] matches the predefined shop PIN.
  static bool verifyPin(String pin) => pin == predefinedPin;
}
