import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../firebase_config.dart';

class AuthState {
  const AuthState({
    this.isSubmitting = false,
    this.message,
    this.signedIn = false,
  });

  final bool isSubmitting;
  final String? message;
  final bool signedIn;
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(const AuthState());

  static Future<void>? _googleSignInInitialization;

  FirebaseAuth? get _auth =>
      FirebaseConfig.isReady ? FirebaseAuth.instance : null;

  void clearMessage() {
    if (state.message != null) emit(const AuthState());
  }

  Future<bool> register(String email, String password) async => _run(() async {
    final credential = await _requiredAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user?.sendEmailVerification();
    return null;
  });

  Future<bool> login(
    String email,
    String password, {
    bool admin = false,
  }) async => _run(() async {
    final credential = await _requiredAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if (admin) {
      final claims =
          (await credential.user!.getIdTokenResult(true)).claims ?? const {};
      if (claims['admin'] != true) {
        await _requiredAuth.signOut();
        throw FirebaseAuthException(code: 'not-admin');
      }
    }
    return null;
  });

  Future<bool> resetPassword(String email) async => _run(() async {
    await _requiredAuth.sendPasswordResetEmail(email: email.trim());
    return 'If an account exists for that email, a reset link has been sent.';
  });

  Future<bool> continueWithGoogle({bool adminOnly = false}) async {
    return _run(() async {
      late final UserCredential credential;
      if (kIsWeb) {
        credential = await _requiredAuth.signInWithPopup(GoogleAuthProvider());
      } else {
        await _initializeNativeGoogleSignIn();
        final googleUser = await GoogleSignIn.instance.authenticate();
        final idToken = googleUser.authentication.idToken;
        if (idToken == null || idToken.isEmpty) {
          throw FirebaseAuthException(code: 'invalid-credential');
        }
        credential = await _requiredAuth.signInWithCredential(
          GoogleAuthProvider.credential(idToken: idToken),
        );
      }
      if (adminOnly) {
        final claims =
            (await credential.user!.getIdTokenResult(true)).claims ?? const {};
        if (claims['admin'] != true) {
          await _requiredAuth.signOut();
          throw FirebaseAuthException(code: 'not-admin');
        }
      }
      return null;
    });
  }

  Future<void> _initializeNativeGoogleSignIn() {
    return _googleSignInInitialization ??= GoogleSignIn.instance.initialize(
      serverClientId: FirebaseConfig.googleServerClientId,
      clientId: defaultTargetPlatform == TargetPlatform.iOS
          ? FirebaseConfig.googleIosClientId
          : null,
    );
  }

  FirebaseAuth get _requiredAuth {
    final auth = _auth;
    if (auth == null)
      throw FirebaseAuthException(code: 'firebase-not-configured');
    return auth;
  }

  Future<bool> _run(Future<String?> Function() action) async {
    if (state.isSubmitting) return false;
    emit(const AuthState(isSubmitting: true));
    try {
      final message = await action();
      final signedIn = _auth?.currentUser != null && message == null;
      emit(AuthState(message: message, signedIn: signedIn));
      return signedIn;
    } on FirebaseAuthException catch (error) {
      emit(AuthState(message: _messageFor(error.code)));
      return false;
    } on GoogleSignInException catch (error) {
      final message = switch (error.code) {
        GoogleSignInExceptionCode.canceled => 'Google sign-in was cancelled.',
        GoogleSignInExceptionCode.clientConfigurationError => 'Google sign-in setup is incomplete. Add the Android SHA-1 fingerprint in Firebase Project settings, then rebuild.',
        GoogleSignInExceptionCode.providerConfigurationError =>
          'Google sign-in is not enabled for this Firebase project.',
        _ => 'Google sign-in could not start. Check the app configuration and try again.',
      };
      emit(AuthState(message: message));
      return false;
    } catch (_) {
      emit(const AuthState(message: 'Something went wrong. Please try again.'));
      return false;
    }
  }

  String _messageFor(String code) => switch (code) {
    'firebase-not-configured' =>
      kIsWeb
          ? 'Firebase web settings are missing. Register a Web app and add its App ID and API key to firebase.local.json, then restart the app.'
          : 'Firebase settings are missing. Launch with --dart-define-from-file=firebase.local.json after adding this platform’s API key.',
    'invalid-email' => 'Enter a valid email address.',
    'user-not-found' ||
    'wrong-password' ||
    'invalid-credential' => 'The email or password is incorrect.',
    'email-already-in-use' => 'An account already exists for this email.',
    'weak-password' => 'Choose a stronger password (at least 8 characters).',
    'too-many-requests' => 'Too many attempts. Please wait and try again.',
    'network-request-failed' =>
      'Connection problem. Check your internet and try again.',
    'popup-closed-by-user' => 'Google sign-in was cancelled.',
    'not-admin' => 'This account does not have administrator access.',
    'operation-not-allowed' =>
      'This sign-in method is not enabled in Firebase Authentication.',
    _ => 'Unable to sign in. Please check your details and try again.',
  };
}
