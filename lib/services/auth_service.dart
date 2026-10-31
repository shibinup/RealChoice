import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
class AuthService {


  /// The shop PIN that must be entered on both login and the PIN page.
  static const String predefinedPin = '1234';



  // Login status

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  // Get currently logged-in user
  static User? get currentUser => _auth.currentUser;

  // Check login status
  static bool get isLoggedIn => currentUser != null;

  // Get previously logged-in user's email
  static String? get currentEmail => currentUser?.email;


  // Listen to login/logout changes
  static Stream<User?> get authStateChanges =>
      _auth.authStateChanges();




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
      // If the error code indicates the user doesn't exist, create it.
      // Note: 'user-not-found' is only thrown if protection is disabled in Firebase Console.
      if (e.code == 'user-not-found') {
        try {
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: cleanEmail,
            password: password,
          );
        } on FirebaseAuthException catch (createErr) {
          throw Exception('Failed to auto-create auth account: ${createErr.message}');
        }
      } else if (e.code == 'invalid-credential') {
        // This usually means wrong password if the user already exists
        throw Exception('Invalid email or password.');
      } else {
        rethrow;
      }
    }
  }

  /// Signs out of Firebase and clears the local session flag.
  static Future<void> logout() async {
    await _auth.signOut();
  }

  /// Returns true when [pin] matches the predefined shop PIN.
  static bool verifyPin(String pin) => pin == predefinedPin;
}
