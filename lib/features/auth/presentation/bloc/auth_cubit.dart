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
    this.registrationEmail,
  });

  final bool isSubmitting;
  final String? message;
  final bool signedIn;
  final bool userNotRegistered;
  final String? registrationEmail;
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(const AuthState());

  static Future<void>? _googleSignInInitialization;

  FirebaseAuth? get _auth =>
      FirebaseConfig.isReady ? FirebaseAuth.instance : null;

  void clearMessage() {
    if (state.message != null) emit(const AuthState());
  }

  Future<bool> register(String email, String password) async {
    if (state.isSubmitting) return false;
    final normalizedEmail = email.trim();
    emit(const AuthState(isSubmitting: true));
    try {
      _logAuth(
        '[1/2 Register] Creating an Argon2id password account through the Z8 API...',
      );
      await BackendApi.registerWithPassword(normalizedEmail, password);
      _logAuth('[2/2 Register] Account created; email verification code sent.');
      emit(AuthState(registrationEmail: normalizedEmail));
    } on BackendApiException catch (error) {
      _logAuth(
        '[Register Error] Backend code=${error.code}, status=${error.statusCode}.',
      );
      emit(AuthState(message: error.message));
    } catch (error) {
      _logAuth('[Register Error] Unexpected error: $error');
      emit(
        const AuthState(
          message: 'We could not create your account. Please try again.',
        ),
      );
    }
    return false;
  }

  Future<bool> verifyRegistration(String email, String code) => _run(() async {
    final session = await BackendApi.verifyPasswordRegistration(
      email.trim(),
      code.trim(),
    );
    final customToken = session['firebaseCustomToken'] as String?;
    if (customToken == null || customToken.isEmpty) {
      throw const BackendApiException(
        'invalid_response',
        'The Z8 service returned an invalid session.',
      );
    }
    await _requiredAuth.signInWithCustomToken(customToken);
    _logAuth(
      '[Registration] Email verification passed; custom session established.',
    );
    return null;
  });

  Future<bool> resendRegistrationCode(String email) async {
    if (state.isSubmitting) return false;
    emit(const AuthState(isSubmitting: true));
    try {
      await BackendApi.resendRegistrationCode(email.trim());
      emit(
        AuthState(
          registrationEmail: email.trim(),
          message:
              'If the account needs verification, a new code has been sent.',
        ),
      );
      return true;
    } on BackendApiException catch (error) {
      emit(AuthState(registrationEmail: email.trim(), message: error.message));
      return false;
    } catch (_) {
      emit(
        AuthState(
          registrationEmail: email.trim(),
          message: 'We could not send a new code. Please try again.',
        ),
      );
      return false;
    }
  }

  Future<bool> login(
    String email,
    String password, {
    bool admin = false,
  }) async => _run(() async {
    _logAuth(
      '[1/3 Login] Starting email login for "$email" (admin: $admin)...',
    );
    late Map<String, dynamic> session;
    try {
      session = await BackendApi.loginWithPassword(email.trim(), password);
    } on BackendApiException catch (error) {
      if (error.code != 'password_migration_required') rethrow;
      _logAuth(
        '[2/4 Login] Migrating this legacy password to the PostgreSQL Argon2id hash...',
      );
      final legacy = await _requiredAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final legacyToken = await legacy.user!.getIdToken(true);
      if (legacyToken == null)
        throw FirebaseAuthException(code: 'invalid-credential');
      await BackendApi.migrateLegacyPassword(legacyToken, password);
      await _requiredAuth.signOut();
      session = await BackendApi.loginWithPassword(email.trim(), password);
    }
    final customToken = session['firebaseCustomToken'] as String?;
    if (customToken == null || customToken.isEmpty) {
      throw const BackendApiException(
        'invalid_response',
        'The Z8 service returned an invalid session.',
      );
    }
    final credential = await _requiredAuth.signInWithCustomToken(customToken);
    final user = credential.user!;
    _logAuth(
      '[2/3 Login] Argon2id password verified; checking PostgreSQL role...',
    );
    try {
      final profile = await BackendApi.getMe((await user.getIdToken(true))!);
      _logAuth(
        '[3/3 Login] Backend confirmed role: ${profile['role'] ?? 'unknown'}',
      );
      if (admin && profile['role'] != 'admin') {
        _logAuth('[Login Error] User is not an admin.');
        await _requiredAuth.signOut();
        throw FirebaseAuthException(code: 'not-admin');
      }
      if (!admin && profile['role'] == 'admin') {
        _logAuth(
          '[Login Error] Admin account tried to sign in via user portal.',
        );
        await _requiredAuth.signOut();
        throw FirebaseAuthException(code: 'admin-user-portal');
      }
    } catch (e) {
      _logAuth('[Login Error] Profile check failed: $e');
      final invalidSession =
          e is FirebaseAuthException &&
          const {
            'user-disabled',
            'user-not-found',
            'user-token-expired',
            'invalid-user-token',
          }.contains(e.code);
      final rejectedByBackend =
          e is BackendApiException &&
          (e.code == 'user_not_registered' ||
              e.statusCode == 401 ||
              e.statusCode == 403);
      if ((invalidSession || rejectedByBackend) &&
          _requiredAuth.currentUser?.uid == user.uid) {
        await _requiredAuth.signOut();
      }
      rethrow;
    }
    return null;
  });

  Future<void> requestPasswordReset(String email) async {
    await _run(() async {
      _logAuth('Requesting a Z8 password reset code...');
      await BackendApi.requestPasswordReset(email.trim());
      return null;
    });
  }

  Future<void> confirmPasswordReset({
    required String email,
    required String token,
    required String password,
  }) async {
    await _run(() async {
      final result = await BackendApi.confirmPasswordReset(
        email: email.trim(),
        token: token.trim(),
        password: password,
      );
      return result['message'] as String? ?? 'Your password has been reset.';
    });
  }

  Future<bool> continueWithGoogle({bool adminOnly = false}) async {
    return _run(() async {
      _logAuth('--- GOOGLE SIGN-IN FLOW STARTED ---');
      _logAuth(
        '[Step 1/5] Platform: ${defaultTargetPlatform.name}, adminOnly: $adminOnly',
      );
      if (kIsWeb) {
        throw const BackendApiException(
          'unsupported_platform',
          'Use the Z8 mobile app to sign in with Google.',
        );
      }
      _logAuth(
        '[Step 1/5] Initializing GoogleSignIn (serverClientId: ${FirebaseConfig.googleServerClientId})...',
      );
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
          final payload = jsonDecode(
            utf8.decode(base64Url.decode(normalized)),
          ) as Map<String, dynamic>;
          final expSec = payload['exp'] as int?;
          final expDate = expSec != null
              ? DateTime.fromMillisecondsSinceEpoch(expSec * 1000)
                    .toIso8601String()
              : 'unknown';
          _logAuth(
            '[Step 3/5 Token Claims] aud: "${payload['aud']}", '
            'iss: "${payload['iss']}", '
            'email: "${payload['email']}", '
            'exp: $expSec ($expDate)',
          );
        }
      } catch (err) {
        _logAuth(
          '[Step 3/5 Warning] Could not parse unverified token payload: $err',
        );
      }

      _logAuth(
        '[Step 4/5] Sending ID token to backend: POST ${BackendApi.baseUrl}/auth/google/session ...',
      );
      late final Map<String, dynamic> session;
      try {
        session = await BackendApi.exchangeGoogleIdToken(idToken);
        _logAuth(
          '[Step 4/5 Success] Backend verified token! Account role: ${session['role']}, email: ${session['email']}',
        );
      } on BackendApiException catch (error) {
        _logAuth(
          '[Step 4/5 Rejection] Backend returned error: ${error.toString()} (statusCode: ${error.statusCode})',
        );
        await GoogleSignIn.instance.signOut();
        rethrow;
      }
      final role = session['role'] as String?;
      if (adminOnly && role != 'admin') {
        _logAuth('[Access Denied] User role is "$role", required: "admin".');
        throw FirebaseAuthException(code: 'not-admin');
      }
      if (!adminOnly && role == 'admin') {
        _logAuth(
          '[Access Denied] Admin account tried to sign in via user portal.',
        );
        await GoogleSignIn.instance.signOut();
        throw FirebaseAuthException(code: 'admin-user-portal');
      }
      final customToken = session['firebaseCustomToken'] as String?;
      if (customToken == null || customToken.isEmpty) {
        _logAuth(
          '[Step 4/5 Error] Backend response missing firebaseCustomToken.',
        );
        throw FirebaseAuthException(code: 'invalid-credential');
      }
      _logAuth(
        '[Step 5/5] Signing into Firebase Auth with returned custom token...',
      );
      final cred = await _requiredAuth.signInWithCustomToken(customToken);
      _logAuth(
        '[Step 5/5 Success] Firebase Auth sign-in successful! User UID: ${cred.user?.uid}',
      );
      if (adminOnly) {
        final claims =
            (await _requiredAuth.currentUser!.getIdTokenResult(true)).claims ??
            const {};
        _logAuth(
          '[Admin Check] Firebase token claims: $claims, admin=${claims['admin']}',
        );
        if (claims['admin'] != true) {
          _logAuth(
            '[Access Denied] Firebase claims do not have admin=true. Signing out.',
          );
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
      _logAuth(
        '[Auth Error] FirebaseAuthException: code=${error.code}, message=${error.message}',
      );
      emit(AuthState(message: _messageFor(error.code)));
      return false;
    } on BackendApiException catch (error) {
      _logAuth(
        '[Auth Error] BackendApiException: code=${error.code}, status=${error.statusCode}, message=${error.toString()}',
      );
      final sessionCanBeRetried =
          _auth?.currentUser != null &&
          error.code != 'user_not_registered' &&
          error.statusCode != 401 &&
          error.statusCode != 403;
      emit(
        AuthState(
          message: error.message,
          signedIn: sessionCanBeRetried,
          userNotRegistered: error.code == 'user_not_registered',
        ),
      );
      return sessionCanBeRetried;
    } on GoogleSignInException catch (error) {
      _logAuth(
        '[Auth Error] GoogleSignInException: code=${error.code.name}, description=${error.description}',
      );
      final message = switch (error.code) {
        GoogleSignInExceptionCode.canceled => 'Google sign-in was cancelled. Tap Continue with Google to try again.',
        GoogleSignInExceptionCode.clientConfigurationError =>
          'Google sign-in is not configured correctly. Please try again later.',
        GoogleSignInExceptionCode.providerConfigurationError =>
          'Google sign-in is temporarily unavailable. Please try again later.',
        _ => 'We could not sign you in with Google. Please try again or use email and password.',
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
    'admin-user-portal' => 'This email is registered as an administrator. Please sign in via the Admin sign-in page.',
    'admin_account_exists' => 'This email is registered as an administrator. Please sign in via the Admin sign-in page.',
    'operation-not-allowed' => 'Email and password sign-in is disabled. In Firebase Console, open Authentication > Sign-in method, enable Email/Password, and save.',
    _ => 'Unable to sign in. Please check your details and try again.',
  };
}
