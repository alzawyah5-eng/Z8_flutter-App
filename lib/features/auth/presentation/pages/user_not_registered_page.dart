import 'package:flutter/material.dart';

import '../widgets/auth_shell.dart';

class UserNotRegisteredPage extends StatelessWidget {
  const UserNotRegisteredPage({super.key});

  @override
  Widget build(BuildContext context) => AuthShell(
    icon: Icons.gpp_bad_outlined,
    title: 'Access restricted',
    subtitle:
        'This account is not registered for Z8. Contact the administrator to request access.',
    form: Center(
      child: OutlinedButton.icon(
        onPressed: () => Navigator.pushNamedAndRemoveUntil(
          context,
          '/login',
          (route) => false,
        ),
        icon: const Icon(Icons.arrow_back),
        label: const Text('Back to sign in'),
      ),
    ),
    footer: const SizedBox.shrink(),
  );
}
