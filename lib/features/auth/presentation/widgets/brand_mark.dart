import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({this.light = false, super.key});

  final bool light;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: light ? Colors.white70 : AppTheme.border),
        color: light
            ? Colors.white.withValues(alpha: .12)
            : const Color(0xFFF6F2E9),
      ),
      alignment: Alignment.center,
      child: light
          ? const Text(
              'Z8',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'serif',
                fontSize: 16,
              ),
            )
          : Image.asset(
              'assets/images/z8-logo.png',
              width: 22,
              height: 22,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Text(
                'Z8',
                style: TextStyle(
                  color: Color(0xFF51082F),
                  fontFamily: 'serif',
                  fontSize: 16,
                ),
              ),
            ),
    );
  }
}
