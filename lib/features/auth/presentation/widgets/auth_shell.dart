import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import 'auth_brand_panel.dart';
import 'brand_mark.dart';

class AuthShell extends StatelessWidget {
  const AuthShell({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.form,
    required this.footer,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget form;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1000;
            final contentHeight = constraints.maxHeight < 700
                ? 700.0
                : constraints.maxHeight;
            if (wide) {
              return SingleChildScrollView(
                child: SizedBox(
                  height: contentHeight,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 6,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
                          child: const AuthBrandPanel(),
                        ),
                      ),
                      Expanded(
                        flex: 6,
                        child: Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                              vertical: 32,
                              horizontal: 36,
                            ),
                            child: _AuthContent(
                              icon: icon,
                              title: title,
                              subtitle: subtitle,
                              form: form,
                              footer: footer,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
              child: Column(
                children: [
                  const _CompactBrand(),
                  const SizedBox(height: 40),
                  _AuthContent(
                    icon: icon,
                    title: title,
                    subtitle: subtitle,
                    form: form,
                    footer: footer,
                    alignLeft: true,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AuthContent extends StatelessWidget {
  const _AuthContent({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.form,
    required this.footer,
    this.alignLeft = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget form;
  final Widget footer;
  final bool alignLeft;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(
        crossAxisAlignment: alignLeft
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F0F3),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppTheme.plum, size: 21),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: MediaQuery.sizeOf(context).width < 640 ? 30 : 34,
            ),
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 28),
          form,
          const SizedBox(height: 24),
          footer,
          const SizedBox(height: 28),
          const Text(
            'A little clarity for your everyday cards.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _CompactBrand extends StatelessWidget {
  const _CompactBrand();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        BrandMark(),
        SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Z8 Card Manager',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              'Card programme console',
              style: TextStyle(color: AppTheme.muted, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}
