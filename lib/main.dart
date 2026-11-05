import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app/app.dart';
import 'firebase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseConfig.isReady = false;
  if (FirebaseConfig.isConfigured) {
    try {
      await Firebase.initializeApp(options: FirebaseConfig.options);
      FirebaseConfig.isReady = true;
    } catch (_) {
      // Keep the screens available and report setup problems when auth is used.
    }
  }
  runApp(const Z8App());
}
