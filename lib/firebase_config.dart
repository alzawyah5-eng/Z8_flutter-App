import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// These are public Firebase client settings for this app. Override them with
/// --dart-define values when building against a different Firebase project.
/// Never place a service-account credential or private key in the client app.
class FirebaseConfig {
  static bool isReady = false;
  static const _defaultApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _androidApiKey = String.fromEnvironment(
    'FIREBASE_ANDROID_API_KEY',
    defaultValue: 'AIzaSyCJ2BAJoQb3bipWplLxHZwGDw1eYgfCHQs',
  );
  static const _iosApiKey = String.fromEnvironment(
    'FIREBASE_IOS_API_KEY',
    defaultValue: 'AIzaSyAK50N6VzXN13HjbTdbcNTqO9h89zqH68A',
  );
  static const _webApiKey = String.fromEnvironment(
    'FIREBASE_WEB_API_KEY',
    defaultValue: 'AIzaSyAL37U0tCssSf9HSzDKtmmaXgS0uximZoE',
  );
  static const _androidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
    defaultValue: '1:533283927028:android:052d10822fca6cfad73fa1',
  );
  static const _iosAppId = String.fromEnvironment(
    'FIREBASE_IOS_APP_ID',
    defaultValue: '1:533283927028:ios:b6f850056061ad3ad73fa1',
  );
  static const _webAppId = String.fromEnvironment(
    'FIREBASE_WEB_APP_ID',
    defaultValue: '1:533283927028:web:8ca085c9f349c20bd73fa1',
  );
  static const _messagingSenderId = String.fromEnvironment(
    'FIREBASE_SENDER_ID',
    defaultValue: '533283927028',
  );
  static const _projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'z8-portal',
  );
  static const _authDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
    defaultValue: 'z8-portal.firebaseapp.com',
  );
  static const _storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
    defaultValue: 'z8-portal.firebasestorage.app',
  );
  static const googleServerClientId = String.fromEnvironment(
    'FIREBASE_GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '533283927028-9f8gpqfs98s82gd6gv8qcvdqr7pgj4uq.apps.googleusercontent.com',
  );
  static const googleIosClientId = String.fromEnvironment(
    'FIREBASE_GOOGLE_IOS_CLIENT_ID',
    defaultValue: '533283927028-dce43ejimfos4405k9u1fm3jk3toknge.apps.googleusercontent.com',
  );

  static String get _appId {
    if (kIsWeb) return _webAppId;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => _androidAppId,
      TargetPlatform.iOS => _iosAppId,
      _ => '',
    };
  }

  static String get _apiKey {
    if (kIsWeb) return _webApiKey.isNotEmpty ? _webApiKey : _defaultApiKey;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android =>
        _androidApiKey.isNotEmpty ? _androidApiKey : _defaultApiKey,
      TargetPlatform.iOS => _iosApiKey.isNotEmpty ? _iosApiKey : _defaultApiKey,
      _ => _defaultApiKey,
    };
  }

  static bool get isConfigured =>
      _apiKey.isNotEmpty &&
      _appId.isNotEmpty &&
      _messagingSenderId.isNotEmpty &&
      _projectId.isNotEmpty &&
      (!kIsWeb || _authDomain.isNotEmpty);

  static FirebaseOptions get options => FirebaseOptions(
    apiKey: _apiKey,
    appId: _appId,
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    authDomain: _authDomain,
    storageBucket: _storageBucket.isEmpty ? null : _storageBucket,
  );
}
