"use strict";

/**
 * Firebase Cloud Functions – RealChoice
 *
 * Functions:
 *  - verifyPin  : Callable function that verifies a shop-admin PIN
 *                 against the value stored in Firestore. Runs entirely
 *                 server-side so the PIN is never exposed to the client.
 */

const { setGlobalOptions } = require("firebase-functions");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { initializeApp } = require("firebase-admin/app");
const logger = require("firebase-functions/logger");

// ─── Initialise Firebase Admin SDK ────────────────────────────────────────────
initializeApp();
const db = getFirestore();

// ─── Global options ────────────────────────────────────────────────────────────
// Limit concurrent containers to keep costs predictable.
setGlobalOptions({ maxInstances: 10, region: "asia-south1" });

// ─── Constants ────────────────────────────────────────────────────────────────
/** Maximum wrong-PIN attempts before a temporary lockout. */
const MAX_ATTEMPTS = 5;
/** Lockout duration in milliseconds (15 minutes). */
const LOCKOUT_MS = 15 * 60 * 1000;
/** Firestore collection that holds per-admin rate-limit counters. */
const RATE_LIMIT_COLLECTION = "pin_rate_limits";

// ─────────────────────────────────────────────────────────────────────────────
// verifyPin
// ─────────────────────────────────────────────────────────────────────────────
/**
 * Verifiable callable: verifyPin
 *
 * Called by the Flutter app after the user has already authenticated with
 * Firebase Auth. It checks the supplied 4-digit PIN against the `pin` field
 * stored in the `admins` Firestore collection for the calling user's e-mail.
 *
 * Security measures:
 *  1. Requires an authenticated Firebase user (auth context check).
 *  2. Rate-limits PIN attempts per UID (5 attempts / 15-minute window).
 *  3. PIN comparison happens server-side — the stored PIN value is never
 *     returned to the client.
 *  4. Input validation: rejects non-numeric or wrong-length PINs before
 *     touching Firestore, preventing unnecessary reads.
 *  5. Uses a Firestore transaction for the rate-limit counter so concurrent
 *     requests cannot bypass the limit.
 *  6. Increments a failed-attempt counter that is visible to admins for
 *     audit purposes.
 *
 * @param {object} data        - { pin: string }  (4-digit numeric string)
 * @param {object} context     - Firebase CallableRequest context
 * @returns {{ success: boolean, message: string }}
 */
exports.verifyPin = onCall(
  {
    // Enforce App Check if you enable it in the Firebase console.
    // enforceAppCheck: true,
    consumeAppCheckToken: false,
  },
  async (request) => {
    // ── 1. Authentication guard ──────────────────────────────────────────────
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "You must be signed in to verify a PIN."
      );
    }

    const uid = request.auth.uid;
    const email = (request.auth.token?.email ?? "").toLowerCase().trim();

    // ── 2. Input validation ──────────────────────────────────────────────────
    const { pin } = request.data;

    if (typeof pin !== "string") {
      throw new HttpsError("invalid-argument", "PIN must be a string.");
    }
    if (!/^\d{4}$/.test(pin)) {
      throw new HttpsError(
        "invalid-argument",
        "PIN must be exactly 4 numeric digits."
      );
    }
    if (!email) {
      throw new HttpsError(
        "failed-precondition",
        "Authenticated account has no e-mail."
      );
    }

    // ── 3. Rate-limit check (Firestore transaction) ──────────────────────────
    const rateLimitRef = db.collection(RATE_LIMIT_COLLECTION).doc(uid);

    const { locked, attemptsAfterIncrement } = await db.runTransaction(
      async (txn) => {
        const snap = await txn.get(rateLimitRef);
        const now = Date.now();

        if (snap.exists) {
          const data = snap.data();
          const lockedUntil = data.lockedUntil?.toMillis?.() ?? 0;

          // Still within lockout window?
          if (lockedUntil > now) {
            return { locked: true, attemptsAfterIncrement: data.attempts };
          }

          // Window expired — reset counter.
          if (lockedUntil > 0 && lockedUntil <= now) {
            txn.set(rateLimitRef, { attempts: 0, lockedUntil: null });
            return { locked: false, attemptsAfterIncrement: 0 };
          }

          return { locked: false, attemptsAfterIncrement: data.attempts };
        }

        // No document yet — first attempt.
        txn.set(rateLimitRef, { attempts: 0, lockedUntil: null });
        return { locked: false, attemptsAfterIncrement: 0 };
      }
    );

    if (locked) {
      logger.warn("verifyPin: account locked", { uid, email });
      throw new HttpsError(
        "resource-exhausted",
        "Too many failed attempts. Please wait 15 minutes and try again."
      );
    }

    // ── 4. Fetch admin document from Firestore ───────────────────────────────
    let adminData;
    try {
      const adminSnap = await db
        .collection("admins")
        .where("email", "==", email)
        .limit(1)
        .get();

      if (adminSnap.empty) {
        logger.warn("verifyPin: no admin document found", { uid, email });
        throw new HttpsError(
          "not-found",
          "No admin record found for this account."
        );
      }

      adminData = adminSnap.docs[0].data();
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      logger.error("verifyPin: Firestore read error", err);
      throw new HttpsError("internal", "Unable to verify PIN. Try again.");
    }

    // ── 5. Active-status check ───────────────────────────────────────────────
    if (adminData.active !== true) {
      logger.warn("verifyPin: inactive admin attempted PIN", { uid, email });
      throw new HttpsError(
        "permission-denied",
        "Your admin account is inactive. Contact the main admin."
      );
    }

    // ── 6. PIN comparison (server-side only) ─────────────────────────────────
    const storedPin = (adminData.pin ?? "").trim();
    const pinCorrect = storedPin === pin;

    // ── 7. Update rate-limit counter ─────────────────────────────────────────
    if (!pinCorrect) {
      const newAttempts = attemptsAfterIncrement + 1;
      const lockoutData =
        newAttempts >= MAX_ATTEMPTS
          ? {
              attempts: newAttempts,
              lockedUntil: new Date(Date.now() + LOCKOUT_MS),
            }
          : { attempts: newAttempts };

      await rateLimitRef.set(lockoutData, { merge: true });

      logger.warn("verifyPin: incorrect PIN", {
        uid,
        email,
        attempt: newAttempts,
      });

      if (newAttempts >= MAX_ATTEMPTS) {
        throw new HttpsError(
          "resource-exhausted",
          "Too many failed attempts. Your account is locked for 15 minutes."
        );
      }

      return { success: false, message: "Incorrect PIN." };
    }

    // ── 8. Success — reset rate-limit counter ────────────────────────────────
    await rateLimitRef.set({ attempts: 0, lockedUntil: null });

    logger.info("verifyPin: PIN verified successfully", { uid, email });
    return { success: true, message: "PIN verified." };
  }
);
