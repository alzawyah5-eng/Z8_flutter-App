import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/theme/app_theme.dart';
import '../core/network/network_status_gate.dart';
import '../core/network/backend_api.dart';
import '../core/notifications/notification_navigation.dart';
import '../core/notifications/notification_service.dart';
import '../features/auth/presentation/bloc/auth_cubit.dart';
import '../features/auth/presentation/pages/admin_login_page.dart';
import '../features/auth/presentation/pages/forgot_password_page.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/register_page.dart';
import '../features/auth/presentation/pages/user_not_registered_page.dart';
import '../features/auth/presentation/pages/verify_email_page.dart';
import '../features/workspace/workspace_page.dart';
import '../features/splash/presentation/widgets/z8_splash_screen.dart';
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
          '/not-registered': (_) => const UserNotRegisteredPage(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/signed-in' || settings.name == '/workspace') {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) =>
                  WorkspacePage(initialSection: settings.arguments as String?),
            );
          }
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
  String? _restoreError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreSession());
  }

  bool _isInvalidSession(Object error) {
    if (error is BackendApiException) {
      return error.code == 'user_not_registered' ||
          error.statusCode == 401 ||
          error.statusCode == 403;
    }
    if (error is FirebaseAuthException) {
      return const {
        'user-disabled',
        'user-not-found',
        'user-token-expired',
        'invalid-user-token',
      }.contains(error.code);
    }
    return false;
  }

  Future<void> _restoreSession() async {
    if (!FirebaseConfig.isReady) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    setState(() => _restoreError = null);
    try {
      // Reuse Firebase's persisted refresh token naturally. Forcing a refresh
      // here turned temporary connectivity failures into false logouts.
      final token = await user.getIdToken();
      if (token == null) throw StateError('No Firebase session token.');
      await BackendApi.getMe(token);
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        '/workspace',
        arguments: NotificationService.takePendingSection(),
      );
    } catch (error) {
      if (_isInvalidSession(error)) {
        await FirebaseAuth.instance.signOut();
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      if (mounted) {
        setState(
          () => _restoreError = 'You are still signed in. Z8 could not reconnect just now. Check your connection and retry.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Z8SplashScreen(
    message: _restoreError,
    onRetry: _restoreError == null ? null : _restoreSession,
    loading: _restoreError == null,
  );
}
