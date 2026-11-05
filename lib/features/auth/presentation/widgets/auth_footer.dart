import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class AuthFooter extends StatelessWidget {
  const AuthFooter({required this.prompt, required this.action, required this.onPressed, super.key});

  final String prompt;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(prompt, style: const TextStyle(color: AppTheme.muted, fontSize: 13)),
      TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(foregroundColor: AppTheme.plum, padding: const EdgeInsets.symmetric(horizontal: 4)),
        child: Text(action, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    ],
  );
}
