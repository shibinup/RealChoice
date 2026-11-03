import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Client-side PIN hashing and verification backed by Firestore.
///
/// PINs are **never** stored or transmitted in plain text.  Before any write
/// the PIN is run through SHA-256; on verification the entered PIN is hashed
/// with the same algorithm and compared to the stored digest.
///
/// All operations are performed directly against the `admins` Firestore
/// collection — no Cloud Function is required.
class PinService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Hashing ─────────────────────────────────────────────────────────────────

  /// Returns the lowercase hexadecimal SHA-256 digest of [pin].
  static String hashPin(String pin) {
    final bytes = utf8.encode(pin.trim());
    final digest = sha256.convert(bytes);
    return digest.toString(); // 64-char lowercase hex string
  }

  // ── Verification ─────────────────────────────────────────────────────────────

  /// Verifies the [enteredPin] against the hashed PIN stored in Firestore for
  /// the currently signed-in user.
  ///
  /// Returns `true` when the PIN matches and the account is active.
  /// Throws a descriptive [Exception] for every failure case so the UI can
  /// display a meaningful message without inspecting error codes.
  static Future<bool> verifyPin(String enteredPin) async {
    // ── 1. Must be authenticated ─────────────────────────────────────────────
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Session expired. Please log in again.');
    }

    final email = user.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) {
      throw Exception('Unable to read account email. Please log in again.');
    }

    // ── 2. Fetch the admin document ──────────────────────────────────────────
    final snap = await _db
        .collection('admins')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      throw Exception('No admin account found. Contact the main admin.');
    }

    final data = snap.docs.first.data();

    // ── 3. Account must be active ────────────────────────────────────────────
    if (data['active'] != true) {
      throw Exception('Your account is inactive. Contact the admin.');
    }

    // ── 4. Compare hashes ────────────────────────────────────────────────────
    final storedHash = data['pin']?.toString() ?? '';
    final enteredHash = hashPin(enteredPin);

    return storedHash == enteredHash;
  }
}
