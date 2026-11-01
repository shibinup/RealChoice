import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Provides admin-role helpers backed by the Firestore `admins` collection.
///
/// Firestore document shape expected inside `admins/{docId}`:
///   {
///     "email"  : "user@example.com",   // document identifier
///     "status" : true,                  // true → active user
///     "role"   : "main admin",          // present only on the super-admin doc
///   }
class AdminService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Returns the Firestore document for the currently signed-in user from
  /// the `admins` collection, or `null` if no matching document exists.
  static Future<Map<String, dynamic>?> _currentAdminDoc() async {
    final email = FirebaseAuth.instance.currentUser?.email?.trim().toLowerCase();
    if (email == null) return null;

    final snap = await _db
        .collection('admins')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return snap.docs.first.data();
  }

  /// `true` when the signed-in user has an `admins` doc with `status == true`.
  /// All authorised users (including the main admin) satisfy this condition.
  static Future<bool> isActiveAdmin() async {
    final doc = await _currentAdminDoc();
    if (doc == null) return false;
    return doc['status'] == true;
  }

  /// `true` only when the user's `admins` doc has `role == "main admin"`.
  /// Used to gate the **Manage Admin** bottom-nav tab.
  static Future<bool> isMainAdmin() async {
    final doc = await _currentAdminDoc();
    if (doc == null) return false;
    return doc['active'] == true && doc['role'] == 'mainAdmin';
  }
}
