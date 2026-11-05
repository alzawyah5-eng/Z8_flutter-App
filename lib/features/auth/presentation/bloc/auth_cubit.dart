import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/network/backend_api.dart';
import '../../../../firebase_config.dart';
import '../../../../core/notifications/notification_service.dart';

class AuthState {
  const AuthState({
    this.isSubmitting = false,
    this.message,
    this.signedIn = false,
    this.userNotRegistered = false,
  });

  final bool isSubmitting;
  final String? message;
  final bool signedIn;
  final bool userNotRegistered;
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
    _logAuth('[1/4 Register] Starting Firebase Auth registration for "$email"...');
    final credential = await _requiredAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user!;
    _logAuth('[2/4 Register] Firebase user created: UID=${user.uid}, email=${user.email}');
    try {
      final token = (await user.getIdToken(true))!;
      _logAuth('[3/4 Register] Registering user profile with Backend API at ${BackendApi.baseUrl}/me ...');
      final profile = await BackendApi.registerOrGetMe(token);
      _logAuth('[3/4 Register] Backend registered user successfully! Role: ${profile['role']}');
      await user.getIdToken(true);
      _logAuth('[4/4 Register] Sending email verification to "$email"...');
      await user.sendEmailVerification();
      _logAuth('[4/4 Register] Email verification sent.');
    } catch (e) {
      _logAuth('[Register Error] Backend/Verification step failed: $e. Signing out.');
      await _requiredAuth.signOut();
      rethrow;
    }
    return null;
  });

  Future<bool> login(
    String email,
    String password, {
    bool admin = false,
  }) async => _run(() async {
    _logAuth('[1/3 Login] Starting email login for "$email" (admin: $admin)...');
    final credential = await _requiredAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user!;
    _logAuth('[2/3 Login] Firebase authenticated: UID=${user.uid}. Verifying profile with Backend...');
    try {
      final profile = await BackendApi.getMe((await user.getIdToken())!);
      _logAuth('[3/3 Login] Backend confirmed user profile: Role: ${profile['role'] ?? 'unknown'}');
      await user.getIdToken(true);
      if (admin && profile['role'] != 'admin') {
        _logAuth('[Login Error] User is not an admin.');
        await _requiredAuth.signOut();
        throw FirebaseAuthException(code: 'not-admin');
      }
    } catch (e) {
      _logAuth('[Login Error] Profile check failed: $e');
      if (_requiredAuth.currentUser?.uid == user.uid) {
        await _requiredAuth.signOut();
      }
      rethrow;
    }
    return null;
  });

  Future<bool> resetPassword(String email) async => _run(() async {
    _logAuth('Sending password reset email to "$email"...');
    await _requiredAuth.sendPasswordResetEmail(email: email.trim());
    return 'If an account exists for that email, a reset link has been sent.';
  });

  Future<bool> continueWithGoogle({bool adminOnly = false}) async {
    return _run(() async {
      _logAuth('--- GOOGLE SIGN-IN FLOW STARTED ---');
      _logAuth('[Step 1/5] Platform: ${defaultTargetPlatform.name}, adminOnly: $adminOnly');
      if (kIsWeb) {
        throw const BackendApiException(
          'unsupported_platform',
          'Use the Z8 mobile app to sign in with Google.',
        );
      }
      _logAuth('[Step 1/5] Initializing GoogleSignIn (serverClientId: ${FirebaseConfig.googleServerClientId})...');
      await _initializeNativeGoogleSignIn();
      _logAuth('[Step 2/5] Opening Google account picker dialog...');
      await GoogleSignIn.instance.signOut();
      final googleUser = await GoogleSignIn.instance.authenticate();
      _logAuth('[Step 3/5] User selected Google account: ${googleUser.email}');
      final idToken = googleUser.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        _logAuth('[Step 3/5 Error] No ID token returned by Google Sign-In.');
        throw FirebaseAuthException(code: 'invalid-credential');
      }

      // Safely inspect JWT payload to log claims directly to terminal
      try {
        final parts = idToken.split('.');
        if (parts.length == 3) {
          final normalized = base64Url.normalize(parts[1]);
          final payload = jsonDecode(utf8.decode(base64Url.decode(normalized))) as Map<String, dynamic>;
          final expSec = payload['exp'] as int?;
          final expDate = expSec != null ? DateTime.fromMillisecondsSinceEpoch(expSec * 1000).toIso8601String() : 'unknown';
          _logAuth(
            '[Step 3/5 Token Claims] aud: "${payload['aud']}", '
            'iss: "${payload['iss']}", '
            'email: "${payload['email']}", '
            'exp: $expSec ($expDate)',
          );
        }
      } catch (err) {
        _logAuth('[Step 3/5 Warning] Could not parse unverified token payload: $err');
      }

      _logAuth('[Step 4/5] Sending ID token to backend: POST ${BackendApi.baseUrl}/auth/google/session ...');
      late final Map<String, dynamic> session;
      try {
        session = await BackendApi.exchangeGoogleIdToken(idToken);
        _logAuth('[Step 4/5 Success] Backend verified token! Account role: ${session['role']}, email: ${session['email']}');
      } on BackendApiException catch (error) {
        _logAuth('[Step 4/5 Rejection] Backend returned error: ${error.toString()} (statusCode: ${error.statusCode})');
        await GoogleSignIn.instance.signOut();
        rethrow;
      }
      final role = session['role'] as String?;
      if (adminOnly && role != 'admin') {
        _logAuth('[Access Denied] User role is "$role", required: "admin".');
        throw FirebaseAuthException(code: 'not-admin');
      }
      final customToken = session['firebaseCustomToken'] as String?;
      if (customToken == null || customToken.isEmpty) {
        _logAuth('[Step 4/5 Error] Backend response missing firebaseCustomToken.');
        throw FirebaseAuthException(code: 'invalid-credential');
      }
      _logAuth('[Step 5/5] Signing into Firebase Auth with returned custom token...');
      final cred = await _requiredAuth.signInWithCustomToken(customToken);
      _logAuth('[Step 5/5 Success] Firebase Auth sign-in successful! User UID: ${cred.user?.uid}');
      if (adminOnly) {
        final claims =
            (await _requiredAuth.currentUser!.getIdTokenResult(true)).claims ??
                const {};
        if (claims['admin'] != true) {
          await _requiredAuth.signOut();
          throw FirebaseAuthException(code: 'not-admin');
        }
      }
      _logAuth('--- GOOGLE SIGN-IN COMPLETED SUCCESSFULLY ---');
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

  static void _logAuth(String message) {
    debugPrint('[Z8 Auth] $message');
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
      if (signedIn) unawaited(NotificationService.registerForCurrentUser());
      emit(AuthState(message: message, signedIn: signedIn));
      return signedIn;
    } on FirebaseAuthException catch (error) {
      _logAuth('[Auth Error] FirebaseAuthException: code=${error.code}, message=${error.message}');
      emit(AuthState(message: _messageFor(error.code)));
      return false;
    } on BackendApiException catch (error) {
      _logAuth('[Auth Error] BackendApiException: code=${error.code}, status=${error.statusCode}, message=${error.toString()}');
      emit(AuthState(
        message: error.message,
        userNotRegistered: error.code == 'user_not_registered',
      ));
      return false;
    } on GoogleSignInException catch (error) {
      _logAuth('[Auth Error] GoogleSignInException: code=${error.code.name}, description=${error.description}');
      final message = switch (error.code) {
        GoogleSignInExceptionCode.canceled =>
          'Google sign-in was cancelled before authentication completed. If you selected an account, check that this Android app has its SHA fingerprints registered in Firebase, then download the updated google-services.json.',
        GoogleSignInExceptionCode.clientConfigurationError => 'Google sign-in setup is incomplete. Add the Android SHA-1 fingerprint in Firebase Project settings, then rebuild.',
        GoogleSignInExceptionCode.providerConfigurationError =>
          'Google sign-in is not enabled for this Firebase project.',
        _ => 'Google sign-in could not start. Check the app configuration and try again.',
      };
      emit(AuthState(message: message));
      return false;
    } catch (error) {
      _logAuth('[Auth Error] Unexpected error: $error');
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
      'Email and password sign-in is disabled. In Firebase Console, open Authentication > Sign-in method, enable Email/Password, and save.',
    _ => 'Unable to sign in. Please check your details and try again.',
  };
}
