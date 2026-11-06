import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'app/app.dart';
import 'firebase_config.dart';
import 'core/notifications/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseConfig.isReady = false;
  if (FirebaseConfig.isConfigured) {
    try {
      await Firebase.initializeApp(options: FirebaseConfig.options);
      FirebaseConfig.isReady = true;
      if (kIsWeb) {
        await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
      }
      await NotificationService.initialize();
    } catch (_) {
      // Keep the screens available and report setup problems when auth is used.
    }
  }
  runApp(const Z8App());
}
