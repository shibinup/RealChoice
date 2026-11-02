import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Provides admin-role helpers and CRUD operations backed by the Firestore
/// `admins` collection.
///
/// Firestore document shape inside `admins/{docId}`:
///   {
///     "email"  : "user@example.com",   // unique admin email
///     "pin"    : "1234",               // 4-digit login PIN (string)
///     "active" : true,                 // true → account is active
///     "role"   : "mainAdmin",          // present only on the super-admin doc
///   }
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

  /// Adds a new admin document. Throws if an admin with [email] already exists.
  ///
  /// The document ID is the normalised email address so it is trivially unique.
  static Future<void> addAdmin({
    required String email,
    required String pin,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    // Guard: reject obviously invalid input.
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      throw Exception('Please enter a valid email address.');
    }
    if (pin.trim().length != 4) {
      throw Exception('PIN must be exactly 4 digits.');
    }

    // Guard: duplicate check.
    final existing = await _db
        .collection('admins')
        .where('email', isEqualTo: cleanEmail)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      throw Exception('An admin with this email already exists.');
    }

    // Use the email as the document ID for easy lookup.
    final docId = cleanEmail.replaceAll(RegExp(r'[.@]'), '_');
    await _db.collection('admins').doc(docId).set({
      'email': cleanEmail,
      'pin': pin.trim(),
      'active': true,
      'role':'subAdmin',
    });
  }

  /// Permanently deletes the admin document identified by [docId].
  static Future<void> deleteAdmin(String docId) async {
    await _db.collection('admins').doc(docId).delete();
  }
}
