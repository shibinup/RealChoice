import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'pin_service.dart';

/// Provides admin-role helpers and CRUD operations backed by the Firestore
/// `admins` collection.
///
/// Firestore document shape inside `admins/{docId}`:
///   ```
///   {
///     "email"    : "user@example.com",   // unique admin email
///     "pin"      : "<sha256-hex>",       // SHA-256 hash of the 4-digit PIN
///     "active"   : true,                 // true → account is active
///     "role"     : "mainAdmin",          // present only on the super-admin doc
///     "uid"      : "firebaseUID",        // Firebase Auth UID of the sub-admin
///   }
///   ```
class AdminService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Internal helpers ────────────────────────────────────────────────────────

  /// Returns the Firestore document for the currently signed-in user from
  /// the `admins` collection, or `null` if no matching document exists.
  static Future<Map<String, dynamic>?> _currentAdminDoc() async {
    final email =
        FirebaseAuth.instance.currentUser?.email?.trim().toLowerCase();
    if (email == null) return null;

    final snap = await _db
        .collection('admins')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return snap.docs.first.data();
  }

  // ── Role checks ─────────────────────────────────────────────────────────────

  /// `true` when the signed-in user has an `admins` doc with `active == true`.
  /// All authorised users (including the main admin) satisfy this condition.
  static Future<bool> isActiveAdmin() async {
    final doc = await _currentAdminDoc();
    if (doc == null) return false;
    return doc['active'] == true;
  }

  /// `true` only when the user's `admins` doc has `role == "mainAdmin"`.
  /// Used to gate the **Manage Admin** bottom-nav tab.
  static Future<bool> isMainAdmin() async {
    final doc = await _currentAdminDoc();
    if (doc == null) return false;
    return doc['active'] == true && doc['role'] == 'mainAdmin';
  }

  // ── Admin management (main admin only) ──────────────────────────────────────

  /// Returns a real-time stream of all documents in the `admins` collection,
  /// ordered by email. Only the main admin should call this.
  static Stream<QuerySnapshot<Map<String, dynamic>>> streamAdmins() {
    return _db.collection('admins').orderBy('email').snapshots();
  }

  /// Adds or reactivates a sub-admin.
  ///
  /// **Existing account (same email already in `admins` collection)**
  ///   → Sets `active: true` and updates the PIN. No Firebase Auth call is
  ///     made – the existing Auth account is reused.
  ///
  /// **New account**
  ///   → Creates a Firebase Auth user via a **secondary FirebaseApp instance**
  ///     (so the main-admin session on the default app is never disturbed),
  ///     then writes a fresh Firestore document.
  ///     The secondary app is deleted immediately after creation.
  ///
  /// Returns a [_AddAdminResult] describing what actually happened.
  /// Throws a descriptive [Exception] on validation or Firebase errors.
  static Future<AddAdminResult> addAdmin({
    required String email,
    required String pin,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    // ── Input validation ─────────────────────────────────────────────────────
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      throw Exception('Please enter a valid email address.');
    }
    if (pin.trim().length != 4) {
      throw Exception('PIN must be exactly 4 digits.');
    }
    if (password.trim().length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }

    // ── Check whether an admins document already exists for this email ───────
    final existingSnap = await _db
        .collection('admins')
        .where('email', isEqualTo: cleanEmail)
        .limit(1)
        .get();

    if (existingSnap.docs.isNotEmpty) {
      // ── CASE A: document exists → reject with a clear error ───────────────
      final existingDoc = existingSnap.docs.first;

      // Protect the main admin document from accidental modification.
      if (existingDoc.data()['role'] == 'mainAdmin') {
        throw Exception('Cannot modify the main admin account.');
      }

      throw Exception(
          'This email is already used. Please use a different email address.');
    }

    // ── CASE B: no document → create Firebase Auth + new Firestore doc ───────
    const secondaryAppName = 'secondaryAdminCreator';
    final defaultOptions = Firebase.app().options;

    // Clean up any leftover secondary app from a previous failed attempt.
    try {
      await Firebase.app(secondaryAppName).delete();
    } catch (_) {}

    late FirebaseApp secondaryApp;
    String uid = '';

    try {
      secondaryApp = await Firebase.initializeApp(
        name: secondaryAppName,
        options: defaultOptions,
      );

      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password.trim(),
      );

      uid = credential.user?.uid ?? '';

      // Sign out the secondary session before teardown.
      await secondaryAuth.signOut();
    } on FirebaseAuthException catch (e) {
      throw Exception(_authErrorMessage(e.code));
    } finally {
      // Always delete the secondary app to free resources.
      try {
        await secondaryApp.delete();
      } catch (_) {}
    }

    // Write the new Firestore admin document.
    // The PIN is stored as a SHA-256 hash — never in plain text.
    final docId = cleanEmail.replaceAll(RegExp(r'[.@]'), '_');
    await _db.collection('admins').doc(docId).set({
      'email': cleanEmail,
      'pin': PinService.hashPin(pin.trim()),
      'active': true,
      'role': 'subAdmin',
      'uid': uid,
    });

    return AddAdminResult.created;
  }

  /// Maps common [FirebaseAuthException] error codes to user-friendly messages.
  static String _authErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        // Auth account exists but no Firestore doc – create the doc only.
        return 'A Firebase Auth account already exists for this email. '
            'Please check the email and try again, or contact support.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled in Firebase Console.';
      default:
        return 'Failed to create account ($code).';
    }
  }

  /// Soft-deletes a sub-admin by setting `active: false` on their Firestore
  /// document. The Firebase Auth account and the document itself are preserved
  /// so the account can be reactivated later via [activateAdmin].
  static Future<void> deactivateAdmin(String docId) async {
    await _db.collection('admins').doc(docId).update({'active': false});
  }

  /// Reactivates a previously deactivated sub-admin by setting `active: true`
  /// on their Firestore document.
  static Future<void> activateAdmin(String docId) async {
    await _db.collection('admins').doc(docId).update({'active': true});
  }
}

// ── Result type ──────────────────────────────────────────────────────────────

/// Describes the outcome of [AdminService.addAdmin].
enum AddAdminResult {
  /// A brand-new Firebase Auth account and Firestore document were created.
  created,

  /// An existing (inactive) Firestore document was reactivated with a new PIN.
  reactivated,
}
