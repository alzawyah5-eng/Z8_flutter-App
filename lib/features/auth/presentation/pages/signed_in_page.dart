import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/auth_shell.dart';
import '../../../../core/notifications/notification_service.dart';

class SignedInPage extends StatelessWidget {
  const SignedInPage({super.key});

  Future<void> _signOut(BuildContext context) async {
    await NotificationService.unregisterCurrentDevice();
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthShell(
        icon: Icons.verified_user_outlined,
        title: 'You are signed in',
        subtitle: 'Your Z8 account is ready.',
        form: Center(
          child: ElevatedButton.icon(
            onPressed: () => _signOut(context),
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ),
        footer: const SizedBox.shrink(),
      );
}
