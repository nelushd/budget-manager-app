import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

String authErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'username-not-found':
        return "We couldn't find an account for that username.";
      case 'username-already-in-use':
        return 'That username is already taken. Please choose another one.';
      case 'invalid-username':
        return 'Enter a username.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect username/email or password.';
      case 'user-not-found':
        return 'No account found for that email.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Choose a stronger password.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      default:
        return error.message ?? 'Something went wrong. Please try again.';
    }
  }

  return error.toString().replaceFirst('Exception: ', '');
}

class AuthService {
  AuthService();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  String _usernameKey(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');

  Future<UserCredential> signUp({
    required String username,
    required String email,
    required String password,
  }) async {
    final usernameKey = _usernameKey(username);
    if (usernameKey.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-username',
        message: 'Enter a username.',
      );
    }

    final usernameDoc = _firestore.collection('usernames').doc(usernameKey);
    if ((await usernameDoc.get()).exists) {
      throw FirebaseAuthException(
        code: 'username-already-in-use',
        message: 'That username is already taken.',
      );
    }

    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-created',
        message: 'The account could not be created.',
      );
    }

    await user.updateDisplayName(username.trim());
    await user.reload();

    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'username': username.trim(),
      'email': email.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await usernameDoc.set({
      'uid': user.uid,
      'email': email.trim(),
    });

    return credential;
  }


  Future<UserCredential> signIn(String usernameOrEmail, String password) async {
    final input = usernameOrEmail.trim();

    if (input.contains('@')) {
      final credential = await _auth.signInWithEmailAndPassword(
        email: input,
        password: password,
      );
      await _backfillUsername(credential.user);
      return credential;
    }

    final usernameKey = _usernameKey(input);
    final mapping = await _firestore.collection('usernames').doc(usernameKey).get();
    if (!mapping.exists) {
      throw FirebaseAuthException(
        code: 'username-not-found',
        message: 'No account found for that username.',
      );
    }

    final email = mapping.data()!['email'] as String;
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> _backfillUsername(User? user) async {
    if (user == null || user.email == null) {
      return;
    }

    final hasDisplayName = user.displayName?.trim().isNotEmpty == true;
    final fallbackUsername = hasDisplayName ? user.displayName!.trim() : user.email!.split('@').first;
    final usernameKey = _usernameKey(fallbackUsername);
    if (usernameKey.isEmpty) {
      return;
    }

    final usernameDoc = _firestore.collection('usernames').doc(usernameKey);
    if ((await usernameDoc.get()).exists) {
      return;
    }

    await usernameDoc.set({
      'uid': user.uid,
      'email': user.email,
    });
    await _firestore.collection('users').doc(user.uid).set({
      'username': fallbackUsername,
    }, SetOptions(merge: true));
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> resetPassword(String usernameOrEmail) async {
    final input = usernameOrEmail.trim();

    if (input.contains('@')) {
      return _auth.sendPasswordResetEmail(email: input);
    }

    final usernameKey = _usernameKey(input);
    final mapping = await _firestore.collection('usernames').doc(usernameKey).get();
    if (!mapping.exists) {
      throw FirebaseAuthException(
        code: 'username-not-found',
        message: 'No account found for that username.',
      );
    }

    final email = mapping.data()!['email'] as String;
    return _auth.sendPasswordResetEmail(email: email);
  }
}
