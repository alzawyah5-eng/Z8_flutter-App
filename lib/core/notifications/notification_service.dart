import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  static const MethodChannel _nativeNotifications = MethodChannel(
    'com.nakhba.z8_portal/notifications',
  );
  static String? _registeredToken;
  static String? _pendingSection;
  static Future<NotificationSettings>? _permissionRequest;
  static bool _permissionPrompted = false;
  static bool _initialized = false;

  static String? takePendingSection() {
    final section = _pendingSection;
    _pendingSection = null;
    return section;
  }

  static Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;
    if (defaultTargetPlatform == TargetPlatform.android) {
      _nativeNotifications.setMethodCallHandler((call) async {
        if (call.method == 'notificationTapped') {
          final link = call.arguments?.toString();
          await _nativeNotifications.invokeMethod<String>(
            'takePendingNotificationLink',
          );
          _openLink(link);
        }
      });
      try {
        final pendingLink = await _nativeNotifications.invokeMethod<String>(
          'takePendingNotificationLink',
        );
        if (pendingLink != null) _openLink(pendingLink);
      } on PlatformException {
        // Older Android builds may not yet expose this channel method.
      } on MissingPluginException {
        // Notifications remain optional if the native host is not rebuilt yet.
      }
    }
    FirebaseMessaging.onBackgroundMessage(z8FirebaseMessagingBackgroundHandler);
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    FirebaseMessaging.onMessage.listen(_showForeground);
    FirebaseMessaging.onMessageOpenedApp.listen(_openMessage);
    // Firebase Installation IDs are not accepted by Firebase Admin's FCM
    // sendEachForMulticast API; retain legacy registration tokens until the
    // server and all installed clients support a compatible delivery path.
    // ignore: deprecated_member_use
    _messaging.onTokenRefresh.listen((token) {
      unawaited(_registerToken(token));
    });
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) _openMessage(initialMessage);
  }

  static Future<void> registerForCurrentUser() async {
    if (kIsWeb || FirebaseAuth.instance.currentUser == null) return;
    try {
      var settings = await _messaging.getNotificationSettings();
      if (!_hasNotificationAccess(settings) && !_permissionPrompted) {
        settings = await _requestPermission();
      }
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        for (var attempt = 0; attempt < 10; attempt++) {
          if (await _messaging.getAPNSToken() != null) break;
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
        if (await _messaging.getAPNSToken() == null) return;
      }
      // ignore: deprecated_member_use
      final token = await _messaging.getToken();
      if (token != null) await _registerToken(token);
    } catch (_) {
      // Notification permission and delivery are optional to account sign-in.
    }
  }

  static Future<void> requestPermissionAtStartup() async {
    if (kIsWeb) return;
    try {
      await _requestPermission();
    } catch (_) {
      // Notification access is optional; sign-in and the workspace remain available.
    }
  }

  static Future<NotificationSettings> _requestPermission() {
    final pending = _permissionRequest;
    if (pending != null) return pending;
    final request = _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    _permissionRequest = request;
    return request.whenComplete(() {
      _permissionPrompted = true;
      _permissionRequest = null;
    });
  }

  static bool _hasNotificationAccess(NotificationSettings settings) =>
      settings.authorizationStatus == AuthorizationStatus.authorized ||
      settings.authorizationStatus == AuthorizationStatus.provisional;

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
      final platform = defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : 'android';
      await BackendApi.registerDevice(idToken, token, platform);
      _registeredToken = token;
    } catch (_) {
      // Token refresh/auth retries will attempt registration again.
    }
  }

  static Future<void> _showForeground(RemoteMessage message) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final notification = message.notification;
    final title = notification?.title?.trim();
    final body = notification?.body?.trim();
    final dataTitle = message.data['title']?.toString().trim();
    final dataBody = message.data['body']?.toString().trim();
    final visibleTitle = (title?.isNotEmpty == true ? title : dataTitle);
    final visibleBody = (body?.isNotEmpty == true ? body : dataBody);
    if ((visibleTitle == null || visibleTitle.isEmpty) &&
        (visibleBody == null || visibleBody.isEmpty)) {
      return;
    }
    try {
      await _nativeNotifications.invokeMethod<void>('showNotification', {
        'title': visibleTitle?.isNotEmpty == true ? visibleTitle : 'Z8 update',
        'body': visibleBody ?? '',
        'link': message.data['link']?.toString() ?? '',
      });
    } on PlatformException {
      // System notification delivery is optional; do not replace it with an in-app banner.
    } on MissingPluginException {
      // A full native rebuild installs this Android notification channel.
    }
  }

  static void _openMessage(RemoteMessage message) {
    _openLink(message.data['link']?.toString());
  }

  static void _openLink(String? link) {
    final signedIn = FirebaseAuth.instance.currentUser != null;
    if (!signedIn) {
      notificationNavigatorKey.currentState?.pushNamed('/login');
      return;
    }
    final path = Uri.tryParse(link ?? '')?.path ?? link ?? '';
    final section = switch (path) {
      final value when value.startsWith('/cards') => 'cards',
      final value when value.startsWith('/activity') => 'activity',
      final value when value.startsWith('/verification') => 'verification',
      final value when value.startsWith('/account') => 'wallet',
      final value when value.startsWith('/admin/funds') => 'funds',
      final value when value.startsWith('/cardholders') => 'clients',
      final value
          when value.startsWith('/admin/connections') ||
              value.startsWith('/settings') =>
        'connection',
      final value when value.startsWith('/admin/support') => 'support',
      final value when value.startsWith('/assistant') => 'assistant',
      _ => 'notifications',
    };
    final navigator = notificationNavigatorKey.currentState;
    if (navigator == null) {
      _pendingSection = section;
      return;
    }
    navigator.pushNamed('/workspace', arguments: section);
  }
}
