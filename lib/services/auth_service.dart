import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user_model.dart';
import 'api_service.dart';

/// Maps a FirebaseAuthException to a calm, helpful Arabic message instead of
/// Firebase's raw English text — so auth feedback guides the user (log in /
/// reset password) rather than showing a scary error.
String friendlyAuthError(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'هذا البريد مسجَّل بالفعل. جرّب تسجيل الدخول، أو استخدم "نسيت كلمة المرور؟".';
      case 'invalid-email':
        return 'صيغة البريد الإلكتروني غير صحيحة.';
      case 'weak-password':
        return 'كلمة المرور ضعيفة — استخدم ٦ أحرف على الأقل.';
      case 'user-not-found':
        return 'لا يوجد حساب بهذا البريد. تأكد منه أو أنشئ حسابًا جديدًا.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
      case 'user-disabled':
        return 'تم تعطيل هذا الحساب. تواصل مع الدعم.';
      case 'too-many-requests':
        return 'محاولات كثيرة. انتظر قليلًا ثم حاول مجددًا.';
      case 'operation-not-allowed':
        return 'تسجيل الدخول بالبريد غير مُفعَّل حاليًا.';
      case 'requires-recent-login':
        return 'لأمان حسابك، سجّل الدخول من جديد ثم أعد المحاولة.';
      case 'network-request-failed':
        return 'تعذّر الاتصال. تحقّق من الإنترنت وحاول مجددًا.';
    }
  }
  return 'حدث خطأ غير متوقع. حاول مرة أخرى.';
}

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ApiService _api = ApiService();

  AppUser? _currentUser;
  bool _isLoading = false;
  bool _isGuest = false;

  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isGuest => _isGuest;
  // A guest (web PWA "open by role") counts as logged-in for routing/UI.
  bool get isLoggedIn => _auth.currentUser != null || _isGuest;
  String? get uid =>
      _auth.currentUser?.uid ?? (_isGuest ? _currentUser?.uid : null);

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Web/PWA "open by role" entry: start a no-login guest session for [role]
  /// so the installable PWA drops straight into that role's home (demo mode).
  /// Personalized / Firestore-backed data may be empty since there's no account.
  void enterGuest(UserRole role) {
    _isGuest = true;
    _currentUser = AppUser(
      uid: 'guest-${role.name}',
      name: role == UserRole.worker
          ? 'فنّي (ضيف)'
          : role == UserRole.admin
          ? 'مشرف (ضيف)'
          : 'زائر',
      email: '',
      role: role,
    );
    notifyListeners();
  }

  /// Sign up with email/password and store user profile in Firestore
  Future<String?> signUp({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    List<String> skills = const [],
    String phone = '',
    double? latitude,
    double? longitude,
    String? address,
    Uint8List? nationalIdFront,
    Uint8List? nationalIdBack,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = AppUser(
        uid: credential.user!.uid,
        name: name,
        email: email,
        phone: phone,
        role: role,
        skills: skills,
        latitude: latitude,
        longitude: longitude,
        address: address,
      );

      await _firestore
          .collection('users')
          .doc(credential.user!.uid)
          .set(user.toMap());

      _currentUser = user;

      _isLoading = false;
      notifyListeners();

      // Copy the new user into the Mongo-backed dashboard. Runs in the
      // background (never blocks signup) but RETRIES, so a Vercel cold start or
      // a transient blip doesn't leave a registered user missing from the
      // dashboard.
      _syncUserWithRetry(user.toApiMap());

      // A registered worker also becomes a Technician record so the admin's
      // Technicians management can see and verify them. Fire-and-forget — a
      // failure here must never block account creation.
      if (role == UserRole.worker) {
        final cats = skills
            .map((s) => s == 'applianceRepair' ? 'appliance_repair' : s)
            .toList();

        // Upload the national ID images (front/back) to Firebase Storage so the
        // admin can review them before verifying the technician. Uses putData
        // (bytes) so it works on both mobile and the web PWA. A failure here
        // must never block account creation — we just sync without the URLs.
        final frontUrl = await _uploadNationalId(
          credential.user!.uid,
          'front',
          nationalIdFront,
        );
        final backUrl = await _uploadNationalId(
          credential.user!.uid,
          'back',
          nationalIdBack,
        );

        _syncTechnicianWithRetry({
          'uid': credential.user!.uid,
          'name': name,
          'email': email,
          'phone': phone,
          'category': cats.isNotEmpty ? cats.first : 'plumbing',
          'categories': cats,
          if (address != null && address.isNotEmpty) 'address': address,
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
          'verificationStatus': 'pending',
          'isVerified': false,
          if (frontUrl != null) 'nationalIdFrontUrl': frontUrl,
          if (backUrl != null) 'nationalIdBackUrl': backUrl,
        });
      }

      return null; // success
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      return friendlyAuthError(e);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return friendlyAuthError(e);
    }
  }

  /// Upload one national ID image to `technicians/<uid>/national_id_<side>.jpg`
  /// and return its download URL. Returns null (never throws) when there are no
  /// bytes or Storage is unavailable, so registration is never blocked.
  Future<String?> _uploadNationalId(
    String uid,
    String side,
    Uint8List? bytes,
  ) async {
    if (bytes == null || bytes.isEmpty) return null;
    try {
      final ref =
          FirebaseStorage.instance.ref('technicians/$uid/national_id_$side.jpg');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  /// Best-effort sync of a user to the Mongo dashboard with retries + backoff.
  /// Non-blocking (callers don't await): a Vercel cold start or transient blip
  /// no longer drops the user from the dashboard. Idempotent — the API upserts
  /// by email, so retries (and re-syncs on login) never create duplicates.
  Future<void> _syncUserWithRetry(
    Map<String, dynamic> map, {
    int attempts = 4,
  }) async {
    for (var i = 0; i < attempts; i++) {
      try {
        await _api.syncUser(map);
        return;
      } catch (_) {
        if (i < attempts - 1) {
          await Future.delayed(Duration(seconds: 2 * (i + 1)));
        }
      }
    }
  }

  /// Best-effort sync of a technician record with retries + backoff. Upserts by
  /// uid server-side, so retries are safe.
  Future<void> _syncTechnicianWithRetry(
    Map<String, dynamic> map, {
    int attempts = 4,
  }) async {
    for (var i = 0; i < attempts; i++) {
      try {
        await _api.syncTechnician(map);
        return;
      } catch (_) {
        if (i < attempts - 1) {
          await Future.delayed(Duration(seconds: 2 * (i + 1)));
        }
      }
    }
  }

  /// Re-push the signed-in user (and their technician record, if a worker) to
  /// the dashboard. Idempotent and non-blocking; used after login/auto-login to
  /// backfill anyone whose sign-up sync didn't land. Intentionally omits
  /// verificationStatus so it never overwrites an admin's verification.
  void _backfillDashboard() {
    final u = _currentUser;
    if (u == null || u.uid.isEmpty || _isGuest) return;
    _syncUserWithRetry(u.toApiMap());
    if (u.role == UserRole.worker) {
      final cats = u.skills
          .map((s) => s == 'applianceRepair' ? 'appliance_repair' : s)
          .toList();
      _syncTechnicianWithRetry({
        'uid': u.uid,
        'name': u.name,
        'email': u.email,
        'phone': u.phone,
        'category': cats.isNotEmpty ? cats.first : 'plumbing',
        'categories': cats,
        if (u.address != null && u.address!.isNotEmpty) 'address': u.address,
        if (u.latitude != null) 'latitude': u.latitude,
        if (u.longitude != null) 'longitude': u.longitude,
      });
    }
  }

  /// Read the signed-in worker's admin-verification status from the dashboard:
  /// 'verified' | 'pending' | 'rejected', or 'unknown' when the backend can't
  /// be reached (so the gate offers a retry instead of wrongly locking out an
  /// already-approved worker). Guests are always 'verified' (web demo).
  Future<String> workerVerificationStatus() async {
    if (_isGuest) return 'verified';
    final id = uid;
    if (id == null || id.isEmpty) return 'pending';
    try {
      final tech = await _api.getTechnicianByUid(id);
      // Guard against an older API that ignores the uid filter and returns some
      // other technician: only trust a record whose uid actually matches.
      if (tech == null || tech['uid'] != id) return 'pending';
      if (tech['isVerified'] == true) return 'verified';
      final status = tech['verificationStatus']?.toString();
      if (status == 'verified') return 'verified';
      if (status == 'rejected') return 'rejected';
      return 'pending';
    } catch (_) {
      return 'unknown';
    }
  }

  /// Sign in with email/password
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _auth.signInWithEmailAndPassword(email: email, password: password);

      await _loadCurrentUser();

      _isLoading = false;
      notifyListeners();

      // Re-sync to the dashboard on every login — this BACKFILLS any account
      // whose original sign-up sync failed (so it can never stay missing from
      // the dashboard). Workers also re-sync their technician record.
      _backfillDashboard();

      return null; // success
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      return friendlyAuthError(e);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return friendlyAuthError(e);
    }
  }

  /// Demo admin sign-in that self-provisions: signs in if the account exists,
  /// otherwise creates it (Firebase Auth + Firestore) with the admin role.
  /// Lets the dashboard's admin operate from the mobile app without a manual
  /// account-setup step.
  Future<String?> signInOrCreateAdmin({
    required String email,
    required String password,
    String name = 'SmartFix Admin',
  }) async {
    final signInError = await signIn(email: email, password: password);
    if (signInError == null) {
      // Ensure the role is admin even if an older doc exists.
      if (_currentUser != null && _currentUser!.role != UserRole.admin) {
        _currentUser = _currentUser!.copyWith();
      }
      return null;
    }
    // Account likely doesn't exist yet → create it as an admin.
    return signUp(
      name: name,
      email: email,
      password: password,
      role: UserRole.admin,
    );
  }

  /// Change the signed-in user's password: re-authenticate with the current
  /// password (required by Firebase for sensitive ops), then update to the new
  /// one. Returns null on success, otherwise a user-facing error message.
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email ?? '';
    if (user == null || email.isEmpty) {
      return 'You must be signed in with an email account to change your password.';
    }
    try {
      final cred = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);
      return null;
    } on FirebaseAuthException catch (e) {
      return friendlyAuthError(e);
    } catch (e) {
      return friendlyAuthError(e);
    }
  }

  /// Send password reset email
  Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return friendlyAuthError(e);
    } catch (e) {
      return friendlyAuthError(e);
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    _currentUser = null;
    _isGuest = false;
    notifyListeners();
  }

  /// Load user profile from Firestore (with timeout to avoid hanging)
  Future<void> _loadCurrentUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 5));
      if (doc.exists) {
        _currentUser = AppUser.fromMap(doc.data()!);
      }
    } catch (_) {
      // Timeout or network error — continue without cached profile
      debugPrint('Could not load user profile, continuing...');
    }
  }

  /// Load user on app start if already signed in (fast, with timeout)
  Future<void> tryAutoLogin() async {
    if (_auth.currentUser != null) {
      await _loadCurrentUser();
      notifyListeners();
      // Backfill the dashboard on app open, so a returning user whose original
      // sync failed still lands in MongoDB.
      _backfillDashboard();
    }
  }

  /// Update the signed-in worker's skills everywhere in one call: local state
  /// (so the profile reflects immediately), Firestore, the Mongo users
  /// collection (User.skills → profile + dashboard Users page), AND the
  /// technician record (Technician.categories → dashboard Technicians page).
  ///
  /// Keyed by the Firebase uid — the technician upsert is by uid, so we never
  /// need the Mongo _id. Guests (no-login PWA demo) keep their choices
  /// in-memory only, exactly as before.
  Future<void> updateSkills(List<String> skills) async {
    final u = _currentUser;
    if (u == null) return;

    // Canonicalize keys: map the legacy camelCase 'applianceRepair' to the
    // snake_case key the rest of the stack uses, drop blanks, and de-dupe
    // while preserving the chosen order.
    final seen = <String>{};
    final cats = <String>[];
    for (final s in skills) {
      final key = (s == 'applianceRepair' ? 'appliance_repair' : s).trim();
      if (key.isNotEmpty && seen.add(key)) cats.add(key);
    }

    _currentUser = u.copyWith(skills: cats);
    notifyListeners();

    if (_isGuest || u.uid.isEmpty) return;

    try {
      await _firestore.collection('users').doc(u.uid).update({
        'skills': cats,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Firestore offline / permission — local + dashboard sync still applied.
    }

    // User.skills → profile + dashboard Users page.
    _syncUserWithRetry(_currentUser!.toApiMap());

    // Technician.categories → dashboard Technicians page. Upserts by uid, so no
    // Mongo _id is needed. Keep the single `category` in sync with the first
    // selection so the category filter/badges keep working. Verification fields
    // are intentionally omitted so an admin's approval is never overwritten.
    if (u.role == UserRole.worker) {
      _syncTechnicianWithRetry({
        'uid': u.uid,
        'name': u.name,
        'email': u.email,
        'phone': u.phone,
        'category': cats.isNotEmpty ? cats.first : 'plumbing',
        'categories': cats,
      });
    }
  }

  /// Update user profile
  Future<void> updateProfile({
    String? name,
    String? phone,
    String? profileImageUrl,
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    if (_currentUser == null) return;

    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (phone != null) updates['phone'] = phone;
    if (profileImageUrl != null) updates['profileImageUrl'] = profileImageUrl;
    if (latitude != null) updates['latitude'] = latitude;
    if (longitude != null) updates['longitude'] = longitude;
    if (address != null) updates['address'] = address;
    updates['updatedAt'] = FieldValue.serverTimestamp();

    await _firestore.collection('users').doc(_currentUser!.uid).update(updates);

    _currentUser = _currentUser!.copyWith(
      name: name,
      phone: phone,
      profileImageUrl: profileImageUrl,
      latitude: latitude,
      longitude: longitude,
      address: address,
    );
    notifyListeners();
  }
}
