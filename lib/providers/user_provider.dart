import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../data/account_merge.dart';

// Providers
final authProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);
final storageProvider = Provider<FirebaseStorage>(
  (ref) => FirebaseStorage.instance,
);
const _googleWebClientId =
    '1047120968895-f56596g53nq4fnkf8n78q1hsl97a8fk7.apps.googleusercontent.com';

final googleSignInProvider = Provider<GoogleSignIn>(
  (ref) => GoogleSignIn(clientId: kIsWeb ? _googleWebClientId : null),
);

// Auth state stream
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authProvider).authStateChanges();
});

// User data state
class UserData {
  final User? user;
  final Map<String, dynamic>? userData;
  final bool isLoading;
  final String? errorMessage;

  /// Goes up each time data made without an account is brought into this
  /// one, so screens that read once (favourites) know to read again.
  final int merges;

  UserData({
    this.user,
    this.userData,
    this.isLoading = false,
    this.errorMessage,
    this.merges = 0,
  });

  bool get isAuthenticated => user != null;

  /// Using the app without an account (no Apple or Google sign-in yet).
  bool get isAnonymous => user?.isAnonymous ?? false;

  UserData copyWith({
    User? user,
    Map<String, dynamic>? userData,
    bool? isLoading,
    String? errorMessage,
    int? merges,
  }) {
    return UserData(
      user: user ?? this.user,
      userData: userData ?? this.userData,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      merges: merges ?? this.merges,
    );
  }
}

// User state notifier
class UserNotifier extends StateNotifier<UserData> {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final GoogleSignIn _googleSignIn;
  final AccountMergeRepository _merge;

  /// Data from an account used without signing in, waiting to be copied
  /// into the account the paddler has just signed in to.
  ({AccountData from, String intoUid})? _pendingMerge;

  UserNotifier(
    this._auth,
    this._firestore,
    this._storage,
    this._googleSignIn, [
    AccountMergeRepository? merge,
  ]) : _merge = merge ?? AccountMergeRepository(_firestore),
       // Start from the session Firebase restored on launch, so a signed-in
       // paddler never sees the sign-in screen flash past.
       super(UserData(user: _auth.currentUser)) {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? user) async {
    // Built fresh rather than with copyWith, which can't clear the user:
    // signing out has to set it back to null.
    state = UserData(
      user: user,
      userData: user?.uid == state.user?.uid ? state.userData : null,
      isLoading: state.isLoading,
      merges: state.merges,
    );

    if (user != null) {
      await _fetchUserData(user.uid);
      if (_pendingMerge?.intoUid == user.uid && state.userData != null) {
        await _applyPendingMerge(user.uid);
      }
    } else {
      state = state.copyWith(userData: null);
    }
  }

  Future<void> _fetchUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        state = state.copyWith(userData: doc.data());
      }
    } catch (e) {
      final errorMessage = 'Failed to fetch user data: $e';
      state = state.copyWith(errorMessage: errorMessage);
      if (kDebugMode) {
        print(errorMessage);
      }
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User canceled the sign-in
        state = state.copyWith(isLoading: false);
        return;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await _signInOrLink(credential);

      await _saveUser(userCredential.user);
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(errorMessage: _getAuthErrorMessage(e));
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to sign in with Google: $e');
      if (kDebugMode) {
        print('Google Sign-In error: $e');
      }
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Try the app without an account (Firebase anonymous auth). Everything
  /// works the same; signing in with Apple or Google later keeps the
  /// logbook, because the anonymous account is linked rather than replaced.
  Future<void> continueAnonymously() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final credential = await _auth.signInAnonymously();
      await _saveUser(credential.user);
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(errorMessage: _getAuthErrorMessage(e));
    } catch (e) {
      state = state.copyWith(errorMessage: "Couldn't continue: $e");
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Signs in with [credential], or, when the current user is anonymous,
  /// links it to that user so their logbook carries over. If the Apple or
  /// Google account already has a Brownpaw account, signs in to that one.
  Future<UserCredential> _signInOrLink(AuthCredential credential) async {
    final current = _auth.currentUser;
    if (current == null || !current.isAnonymous) {
      return _auth.signInWithCredential(credential);
    }
    try {
      final result = await current.linkWithCredential(credential);
      _refreshLinkedUser();
      return result;
    } on FirebaseAuthException catch (e) {
      if (e.code != 'credential-already-in-use') rethrow;
      return _switchToExistingAccount(current, e.credential ?? credential);
    }
  }

  /// The Apple or Google account already has a Brownpaw account, so the
  /// anonymous one can't be linked to it. Signs in to that account and
  /// brings along what was made without one. The anonymous data is read
  /// first, while the rules still allow it; if that read fails the paddler
  /// stays where they were, with everything intact.
  Future<UserCredential> _switchToExistingAccount(
    User anonymous,
    AuthCredential credential,
  ) async {
    final carried = await _merge.snapshot(anonymous.uid);
    final result = await _auth.signInWithCredential(credential);
    final uid = result.user?.uid;
    if (uid != null && !carried.isEmpty) {
      _pendingMerge = (from: carried, intoUid: uid);
    }
    return result;
  }

  /// Copies waiting anonymous data into [uid]'s account. Kept for another
  /// try if it fails.
  Future<void> _applyPendingMerge(String uid) async {
    final pending = _pendingMerge;
    if (pending == null || pending.intoUid != uid) return;
    // Taken off the queue while it runs, so two callers can't copy twice.
    _pendingMerge = null;
    try {
      await _merge.apply(pending.from, uid);
      state = state.copyWith(merges: state.merges + 1);
    } catch (e) {
      _pendingMerge ??= pending;
      debugPrint('Account merge failed, will retry: $e');
    }
  }

  /// [_signInOrLink] for flows that open a browser page or popup.
  Future<UserCredential> _signInOrLinkProvider(AuthProvider provider) async {
    final current = _auth.currentUser;
    if (current == null || !current.isAnonymous) {
      return kIsWeb
          ? _auth.signInWithPopup(provider)
          : _auth.signInWithProvider(provider);
    }
    try {
      final result = kIsWeb
          ? await current.linkWithPopup(provider)
          : await current.linkWithProvider(provider);
      _refreshLinkedUser();
      return result;
    } on FirebaseAuthException catch (e) {
      if (e.code != 'credential-already-in-use' || e.credential == null) {
        rethrow;
      }
      return _switchToExistingAccount(current, e.credential!);
    }
  }

  /// Linking keeps the same uid, so authStateChanges doesn't fire; pick up
  /// the now non-anonymous user by hand.
  void _refreshLinkedUser() {
    final user = _auth.currentUser;
    if (user != null) state = state.copyWith(user: user);
  }

  /// Sign in with Apple on every platform. iPhone, iPad and Mac use
  /// Apple's native sheet (which also gives the name on first sign-in);
  /// Android and the web use Firebase's Apple flow (a browser page or
  /// popup), which needs the Services ID set up in the Firebase console.
  Future<void> signInWithApple() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final native =
          !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS);
      if (native) {
        await _signInWithAppleNative();
      } else {
        final provider = AppleAuthProvider()
          ..addScope('email')
          ..addScope('name');
        final credential = await _signInOrLinkProvider(provider);
        await _saveUser(credential.user);
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code != AuthorizationErrorCode.canceled) {
        state = state.copyWith(
          errorMessage: "Couldn't sign in with Apple: ${e.message}",
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!_appleCancelCodes.contains(e.code)) {
        state = state.copyWith(errorMessage: _getAuthErrorMessage(e));
      }
    } catch (e) {
      state = state.copyWith(errorMessage: "Couldn't sign in with Apple: $e");
      debugPrint('Apple Sign-In error: $e');
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Firebase codes for a paddler closing the Apple window themselves.
  static const _appleCancelCodes = {
    'canceled',
    'popup-closed-by-user',
    'cancelled-popup-request',
    'web-context-canceled',
    'user-cancelled',
  };

  Future<void> _signInWithAppleNative() async {
    final apple = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
    final credential = OAuthProvider('apple.com').credential(
      idToken: apple.identityToken,
      accessToken: apple.authorizationCode,
    );
    final result = await _signInOrLink(credential);
    // Apple gives the name only the first time someone signs in.
    final name = '${apple.givenName ?? ''} ${apple.familyName ?? ''}'.trim();
    if (name.isNotEmpty && (result.user?.displayName ?? '').isEmpty) {
      await result.user?.updateDisplayName(name);
    }
    await _saveUser(result.user, displayName: name.isEmpty ? null : name);
  }

  Future<void> _revokeAppleIfUsed(User user) async {
    final usesApple = user.providerData.any((p) => p.providerId == 'apple.com');
    final native =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);
    if (!usesApple || !native) return;
    final apple = await SignInWithApple.getAppleIDCredential(scopes: const []);
    await user.reauthenticateWithCredential(
      OAuthProvider('apple.com').credential(
        idToken: apple.identityToken,
        accessToken: apple.authorizationCode,
      ),
    );
    await _auth.revokeTokenWithAuthorizationCode(apple.authorizationCode);
  }

  /// Creates the profile on first sign-in, else records the sign-in.
  Future<void> _saveUser(User? user, {String? displayName}) async {
    if (user == null) return;
    final userDoc = _firestore.collection('users').doc(user.uid);
    final snapshot = await userDoc.get();
    // A linked account keeps the Apple or Google details on its provider
    // entries rather than on the user itself.
    String? fromProviders(String? Function(UserInfo) field) {
      for (final p in user.providerData) {
        final value = field(p);
        if (value != null && value.isNotEmpty) return value;
      }
      return null;
    }

    final email = user.email ?? fromProviders((p) => p.email);
    final name =
        displayName ?? user.displayName ?? fromProviders((p) => p.displayName);
    final photo = user.photoURL ?? fromProviders((p) => p.photoURL);
    if (!snapshot.exists) {
      await userDoc.set({
        'uid': user.uid,
        'email': email,
        'displayName': name,
        'photoURL': photo,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      final existing = snapshot.data() ?? {};
      await userDoc.update({
        'lastSignIn': FieldValue.serverTimestamp(),
        if (existing['email'] == null && email != null) 'email': email,
        if (existing['displayName'] == null && name != null)
          'displayName': name,
        if (existing['photoURL'] == null && photo != null) 'photoURL': photo,
      });
    }
    // After the profile exists, so the rules accept the favourites write.
    await _applyPendingMerge(user.uid);
    await _fetchUserData(user.uid);
  }

  Future<void> signOut() async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      // Sign out from Google (will silently fail if not signed in with Google)
      await _googleSignIn.signOut();

      // Sign out from Firebase
      await _auth.signOut();

      state = state.copyWith(userData: null);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to sign out');
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> updateUserData(Map<String, dynamic> data) async {
    if (state.user == null) return;

    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      await _firestore.collection('users').doc(state.user!.uid).update(data);
      await _fetchUserData(state.user!.uid);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to update user data');
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> updateDisplayName(String displayName) async {
    if (state.user == null) return;

    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      await _firestore.collection('users').doc(state.user!.uid).update({
        'displayName': displayName,
      });
      await _fetchUserData(state.user!.uid);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to update display name');
      rethrow;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<String> updatePhotoURL(Uint8List imageBytes, String fileName) async {
    if (state.user == null) throw Exception('User not authenticated');

    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      // Upload image to Firebase Storage
      final ref = _storage.ref().child(
        'user_photos/${state.user!.uid}/$fileName',
      );
      final uploadTask = await ref.putData(
        imageBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      // Get download URL
      final photoURL = await uploadTask.ref.getDownloadURL();

      // Update Firestore
      await _firestore.collection('users').doc(state.user!.uid).update({
        'photoURL': photoURL,
      });

      await _fetchUserData(state.user!.uid);

      return photoURL;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to update photo');
      rethrow;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> deleteAccount() async {
    if (state.user == null) return;

    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      final uid = state.user!.uid;

      // Apple requires apps to revoke its sign-in when an account is
      // deleted. Asking again also counts as the recent sign-in Firebase
      // wants before deleting.
      await _revokeAppleIfUsed(state.user!);

      // Delete the user's logbook entries. Descents live in the top-level
      // `descents` collection, keyed by `userId`.
      await _deleteQuery(
        _firestore.collection('descents').where('userId', isEqualTo: uid),
      );

      // Delete private runs the user added from the log screen.
      await _deleteQuery(
        _firestore
            .collection('river_runs')
            .where('createdBy', isEqualTo: uid)
            .where('verified', isEqualTo: false),
      );

      // Delete the user's flow alerts.
      await _deleteQuery(
        _firestore.collection('flow_alerts').where('userId', isEqualTo: uid),
      );

      // Delete profile photos. Best effort: a missing folder or a storage
      // hiccup shouldn't stop the account from being deleted.
      try {
        final photos = await _storage.ref('user_photos/$uid').listAll();
        await Future.wait(photos.items.map((item) => item.delete()));
      } catch (_) {}

      // Delete the profile document last, since it holds favourites and
      // settings the steps above don't need.
      await _firestore.collection('users').doc(uid).delete();

      // Sign out from Google if signed in
      await _googleSignIn.signOut();

      // Delete Firebase Auth account (this must be done last)
      await state.user!.delete();

      // Clear state
      state = UserData();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        state = state.copyWith(
          errorMessage: 'Please sign in again to delete your account',
        );
      } else {
        state = state.copyWith(errorMessage: _getAuthErrorMessage(e));
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to delete account: $e');
      if (kDebugMode) {
        print('Delete account error: $e');
      }
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Deletes every document matched by [query], in batches small enough
  /// for Firestore's 500-write limit. Safe to re-run if a later step fails.
  Future<void> _deleteQuery(Query<Map<String, dynamic>> query) async {
    while (true) {
      final snapshot = await query.limit(400).get();
      if (snapshot.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  String _getAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'weak-password':
        return 'Password is too weak';
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-disabled':
        return 'This account has been disabled';
      default:
        return 'Authentication error: ${e.message}';
    }
  }
}

// User provider
final userProvider = StateNotifierProvider<UserNotifier, UserData>((ref) {
  final auth = ref.watch(authProvider);
  final firestore = ref.watch(firestoreProvider);
  final storage = ref.watch(storageProvider);
  final googleSignIn = ref.watch(googleSignInProvider);
  return UserNotifier(auth, firestore, storage, googleSignIn);
});
