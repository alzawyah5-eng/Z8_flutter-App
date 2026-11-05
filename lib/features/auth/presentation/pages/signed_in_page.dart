import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/auth_shell.dart';
import '../../../../core/notifications/notification_service.dart';

class SignedInPage extends StatefulWidget {
  const SignedInPage({super.key});

  @override
  State<SignedInPage> createState() => _SignedInPageState();
}

class _SignedInPageState extends State<SignedInPage> {
  Future<void> _signOut(BuildContext context) async {
    await NotificationService.unregisterCurrentDevice();
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  Future<void> _sendTestPush() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Sending a test push now.'),
          duration: Duration(seconds: 3),
        ),
      );
    try {
      final result = await NotificationService.sendTestPush();
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      final deviceCount = result['deviceCount'] as int? ?? 0;
      final sent = result['sent'] as int? ?? 0;
      final message = deviceCount == 0
          ? 'No registered notification device. Allow notifications and sign in again.'
          : sent == 0
          ? 'No push was accepted. Check Firebase Cloud Messaging setup and backend logs.'
          : 'Push accepted for $sent device(s). Check the notification shade.';
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Push test failed: $error')));
    }
  }

  @override
  Widget build(BuildContext context) => AuthShell(
        icon: Icons.verified_user_outlined,
        title: 'You are signed in',
        subtitle: 'Your Z8 account is ready.',
        form: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OutlinedButton.icon(
                onPressed: _sendTestPush,
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text('Test push notification'),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _signOut(context),
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ],
        ),
        footer: const SizedBox.shrink(),
      );
}
