import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  static Future<void> login(
      String email,
      String password,
      String pin,
      ) async {
    // STEP 1: Clean email
    final cleanEmail = email.trim().toLowerCase();

    // STEP 2: Check email in Firestore admins collection
    final adminSnapshot = await FirebaseFirestore.instance
        .collection('admins')
        .where('email', isEqualTo: cleanEmail)
        .limit(1)
        .get();

    // STEP 3: Check whether admin exists
    if (adminSnapshot.docs.isEmpty) {
      throw Exception(
        'No admin account found. Contact the main admin.',
      );
    }

    // STEP 4: Get admin document
    final adminData = adminSnapshot.docs.first.data();

    // STEP 5: Check PIN
    if (adminData['pin'] != pin.trim()) {
      throw Exception('Incorrect PIN.');
    }
    if (adminData['active'] != true) {
      throw Exception('Admin Inactive.');
    }


    // STEP 6: Check Firebase Authentication
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      // STEP 7: If Firebase account doesn't exist,
      // create a new account.

      if (e.code == 'invalid-credential') {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: cleanEmail,
          password: password,
        );
      } else {
        rethrow;
      }
    }

    // STEP 8: Save login status


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
