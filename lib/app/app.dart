import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/theme/app_theme.dart';
import '../core/network/network_status_gate.dart';
import '../core/notifications/notification_navigation.dart';
import '../features/auth/presentation/bloc/auth_cubit.dart';
import '../features/auth/presentation/pages/admin_login_page.dart';
import '../features/auth/presentation/pages/forgot_password_page.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/register_page.dart';
import '../features/auth/presentation/pages/signed_in_page.dart';
import '../features/auth/presentation/pages/user_not_registered_page.dart';

class Z8App extends StatelessWidget {
  const Z8App({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthCubit(),
      child: MaterialApp(
        title: 'Z8 Card Manager',
        debugShowCheckedModeBanner: false,
        navigatorKey: notificationNavigatorKey,
        theme: AppTheme.light,
        builder: (context, child) => NetworkStatusGate(
          child: child ?? const SizedBox.shrink(),
        ),
        initialRoute: '/login',
        routes: {
          '/login': (_) => const LoginPage(),
          '/register': (_) => const RegisterPage(),
          '/forgot-password': (_) => const ForgotPasswordPage(),
          '/admin/login': (_) => const AdminLoginPage(),
          '/signed-in': (_) => const SignedInPage(),
          '/not-registered': (_) => const UserNotRegisteredPage(),
        },
      ),
    );
  }
}
