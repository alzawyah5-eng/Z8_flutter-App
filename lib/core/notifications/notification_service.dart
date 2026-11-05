import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../firebase_config.dart';
import '../network/backend_api.dart';
import 'notification_navigation.dart';

@pragma('vm:entry-point')
Future<void> z8FirebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty && FirebaseConfig.isConfigured) {
    await Firebase.initializeApp(options: FirebaseConfig.options);
  }
}

class NotificationService {
  NotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static StreamSubscription<RemoteMessage>? _openedSubscription;
  static StreamSubscription<String>? _tokenSubscription;
  static String? _registeredToken;
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;
    FirebaseMessaging.onBackgroundMessage(z8FirebaseMessagingBackgroundHandler);
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );
    _foregroundSubscription = FirebaseMessaging.onMessage.listen(_showForeground);
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(_openMessage);
    _tokenSubscription = _messaging.onTokenRefresh.listen((token) {
      unawaited(_registerToken(token));
    });
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) _openMessage(initialMessage);
  }

  static Future<void> registerForCurrentUser() async {
    if (kIsWeb || FirebaseAuth.instance.currentUser == null) return;
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        for (var attempt = 0; attempt < 10; attempt++) {
          if (await _messaging.getAPNSToken() != null) break;
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
        if (await _messaging.getAPNSToken() == null) return;
      }
      final token = await _messaging.getToken();
      if (token != null) await _registerToken(token);
    } catch (_) {
      // Notification permission and delivery are optional to account sign-in.
    }
  }

  static Future<void> unregisterCurrentDevice() async {
    final user = FirebaseAuth.instance.currentUser;
    final token = _registeredToken;
    if (user == null || token == null) return;
    try {
      final idToken = await user.getIdToken();
      if (idToken != null) await BackendApi.removeDevice(idToken, token);
    } catch (_) {
      // A future sign-in will reassign this installation's token to its user.
    }
    _registeredToken = null;
  }

  static Future<void> _registerToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final permission = await _messaging.getNotificationSettings();
      if (permission.authorizationStatus != AuthorizationStatus.authorized &&
          permission.authorizationStatus != AuthorizationStatus.provisional) {
        return;
      }
      final idToken = await user.getIdToken();
      if (idToken == null) return;
      final platform =
          defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
      await BackendApi.registerDevice(idToken, token, platform);
      _registeredToken = token;
    } catch (_) {
      // Token refresh/auth retries will attempt registration again.
    }
  }

  static void _showForeground(RemoteMessage message) {
    final notification = message.notification;
    final context = notificationNavigatorKey.currentContext;
    if (notification == null || context == null) return;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(
          '${notification.title ?? 'Z8'}: '
          '${notification.body ?? 'You have a new update.'}',
        ),
        behavior: SnackBarBehavior.floating,
      ));
  }

  static void _openMessage(RemoteMessage message) {
    final navigator = notificationNavigatorKey.currentState;
    if (navigator == null) return;
    final signedIn = FirebaseAuth.instance.currentUser != null;
    navigator.pushNamed(signedIn ? '/signed-in' : '/login');
  }
}
