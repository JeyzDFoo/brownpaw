import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

// Providers
final authProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);
final storageProvider = Provider<FirebaseStorage>(
  (ref) => FirebaseStorage.instance,
);
final googleSignInProvider = Provider<GoogleSignIn>((ref) => GoogleSignIn());

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

  UserData({
    this.user,
    this.userData,
    this.isLoading = false,
    this.errorMessage,
  });

  bool get isAuthenticated => user != null;

  UserData copyWith({
    User? user,
    Map<String, dynamic>? userData,
    bool? isLoading,
    String? errorMessage,
  }) {
    return UserData(
      user: user ?? this.user,
      userData: userData ?? this.userData,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// User state notifier
class UserNotifier extends StateNotifier<UserData> {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final GoogleSignIn _googleSignIn;

  UserNotifier(this._auth, this._firestore, this._storage, this._googleSignIn)
    : super(UserData()) {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? user) async {
    state = state.copyWith(user: user, errorMessage: null);

    if (user != null) {
      await _fetchUserData(user.uid);
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
      final userCredential = await _auth.signInWithCredential(credential);

      // Create or update user document in Firestore
      if (userCredential.user != null) {
        final userDoc = _firestore
            .collection('users')
            .doc(userCredential.user!.uid);
        final docSnapshot = await userDoc.get();

        if (!docSnapshot.exists) {
          // New user - create document
          await userDoc.set({
            'uid': userCredential.user!.uid,
            'email': userCredential.user!.email,
            'displayName': userCredential.user!.displayName,
            'photoURL': userCredential.user!.photoURL,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } else {
          // Existing user - update last sign in
          await userDoc.update({'lastSignIn': FieldValue.serverTimestamp()});
        }
      }
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

  Future<void> signInWithApple() async {
    // Only available on iOS
    if (!Platform.isIOS) {
      state = state.copyWith(
        errorMessage: 'Apple Sign In is only available on iOS devices',
      );
      return;
    }

    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      // Check if Apple Sign In is available
      final isAvailable = await SignInWithApple.isAvailable();
      if (!isAvailable) {
        state = state.copyWith(
          errorMessage: 'Apple Sign In is not available on this device',
          isLoading: false,
        );
        return;
      }

      // Request Apple ID credential
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // Create OAuth provider credential
      final oAuthProvider = OAuthProvider('apple.com');
      final credential = oAuthProvider.credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      // Sign in to Firebase with the Apple credential
      final userCredential = await _auth.signInWithCredential(credential);

      // Create or update user document in Firestore
      if (userCredential.user != null) {
        final userDoc = _firestore
            .collection('users')
            .doc(userCredential.user!.uid);
        final docSnapshot = await userDoc.get();

        if (!docSnapshot.exists) {
          // New user - create document
          // Apple provides name only on first sign in
          String? displayName;
          if (appleCredential.givenName != null ||
              appleCredential.familyName != null) {
            displayName =
                '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'
                    .trim();
          }

          await userDoc.set({
            'uid': userCredential.user!.uid,
            'email': userCredential.user!.email,
            'displayName': displayName ?? userCredential.user!.displayName,
            'photoURL': userCredential.user!.photoURL,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } else {
          // Existing user - update last sign in
          await userDoc.update({'lastSignIn': FieldValue.serverTimestamp()});
        }
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        // User canceled the sign-in
        state = state.copyWith(isLoading: false);
        return;
      }
      state = state.copyWith(
        errorMessage: 'Apple Sign In failed: ${e.message}',
      );
      if (kDebugMode) {
        print('Apple Sign-In error: $e');
      }
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(errorMessage: _getAuthErrorMessage(e));
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to sign in with Apple: $e');
      if (kDebugMode) {
        print('Apple Sign-In error: $e');
      }
    } finally {
      state = state.copyWith(isLoading: false);
    }
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

      // Delete user document from Firestore
      await _firestore.collection('users').doc(uid).delete();

      // Delete any related user data (favorites, etc.)
      final batch = _firestore.batch();

      // Delete user's favorites
      final favoritesQuery = await _firestore
          .collection('users')
          .doc(uid)
          .collection('favorites')
          .get();

      for (final doc in favoritesQuery.docs) {
        batch.delete(doc.reference);
      }

      // Delete user's descents
      final descentsQuery = await _firestore
          .collection('users')
          .doc(uid)
          .collection('descents')
          .get();

      for (final doc in descentsQuery.docs) {
        batch.delete(doc.reference);
      }

      // Commit the batch delete
      await batch.commit();

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
