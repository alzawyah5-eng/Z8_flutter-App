import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/theme/app_theme.dart';
import '../core/network/network_status_gate.dart';
import '../core/network/backend_api.dart';
import '../core/notifications/notification_navigation.dart';
import '../features/auth/presentation/bloc/auth_cubit.dart';
import '../features/auth/presentation/pages/admin_login_page.dart';
import '../features/auth/presentation/pages/forgot_password_page.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/register_page.dart';
import '../features/auth/presentation/pages/user_not_registered_page.dart';
import '../features/auth/presentation/pages/verify_email_page.dart';
import '../features/workspace/workspace_page.dart';
import '../firebase_config.dart';

class Z8App extends StatelessWidget {
  const Z8App({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthCubit(),
      child: MaterialApp(
        title: 'Z8 Portal',
        debugShowCheckedModeBanner: false,
        navigatorKey: notificationNavigatorKey,
        theme: AppTheme.light,
        builder: (context, child) =>
            NetworkStatusGate(child: child ?? const SizedBox.shrink()),
        initialRoute: _initialRoute,
        routes: {
          '/': (_) => const _AuthEntryPage(),
          '/login': (_) => const LoginPage(),
          '/register': (_) => const RegisterPage(),
          '/forgot-password': (_) => const ForgotPasswordPage(),
          '/admin/login': (_) => const AdminLoginPage(),
          '/signed-in': (_) => const WorkspacePage(),
          '/workspace': (_) => const WorkspacePage(),
          '/not-registered': (_) => const UserNotRegisteredPage(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/verify-email') {
            final email = settings.arguments as String?;
            if (email != null) {
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => VerifyEmailPage(email: email),
              );
            }
          }
          return null;
        },
      ),
    );
  }

  static String get _initialRoute {
    if (!kIsWeb) return '/';
    final fragment = Uri.tryParse(Uri.base.fragment);
    final fragmentPath = fragment?.path;
    if (fragmentPath != null &&
        fragmentPath.isNotEmpty &&
        fragmentPath != '/') {
      return fragmentPath;
    }
    return Uri.base.path == '/' ? '/login' : Uri.base.path;
  }
}

class _AuthEntryPage extends StatefulWidget {
  const _AuthEntryPage();
  @override
  State<_AuthEntryPage> createState() => _AuthEntryPageState();
}

class _AuthEntryPageState extends State<_AuthEntryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!FirebaseConfig.isReady ||
          FirebaseAuth.instance.currentUser == null) {
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      try {
        await BackendApi.getMe(
          (await FirebaseAuth.instance.currentUser!.getIdToken(true))!,
        );
        if (mounted) Navigator.pushReplacementNamed(context, '/workspace');
      } catch (_) {
        await FirebaseAuth.instance.signOut();
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
