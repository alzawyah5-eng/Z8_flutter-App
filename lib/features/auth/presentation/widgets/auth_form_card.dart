import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../bloc/auth_cubit.dart';

class AuthFormCard extends StatelessWidget {
  const AuthFormCard({
    required this.children,
    this.showGoogle = false,
    this.googleAdminOnly = false,
    super.key,
  });

  final List<Widget> children;
  final bool showGoogle;
  final bool googleAdminOnly;

  Future<void> _googleSignIn(BuildContext context) async {
    final success = await context.read<AuthCubit>().continueWithGoogle(
      adminOnly: googleAdminOnly,
    );
    if (success && context.mounted) {
      Navigator.pushReplacementNamed(context, '/signed-in');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 640 ? 20 : 28),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080A1730),
            blurRadius: 20,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showGoogle) ...[
            BlocBuilder<AuthCubit, AuthState>(
              builder: (context, state) => OutlinedButton.icon(
                onPressed: state.isSubmitting
                    ? null
                    : () => _googleSignIn(context),
                icon: state.isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Image.asset(
                        'assets/images/google.png',
                        width: 20,
                        height: 20,
                        errorBuilder: (_, __, ___) => const Text(
                          'G',
                          style: TextStyle(
                            color: Color(0xFF4285F4),
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                      ),
                label: const Text('Continue with Google'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.ink,
                  minimumSize: const Size.fromHeight(48),
                  side: const BorderSide(color: AppTheme.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            const _OrDivider(),
            const SizedBox(height: 22),
          ],
          ...children,
          BlocBuilder<AuthCubit, AuthState>(
            builder: (context, state) => state.message == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      state.message!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.plum,
                        fontSize: 13,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) => const Row(
    children: [
      Expanded(child: Divider(color: AppTheme.border)),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          'OR',
          style: TextStyle(color: AppTheme.muted, fontSize: 12),
        ),
      ),
      Expanded(child: Divider(color: AppTheme.border)),
    ],
  );
}

