import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_cubit.dart';
import '../widgets/auth_action_button.dart';
import '../widgets/auth_form_card.dart';
import '../widgets/auth_shell.dart';
import '../widgets/auth_text_field.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({required this.email, super.key});
  final String email;

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final success = await context.read<AuthCubit>().verifyRegistration(
      widget.email,
      _code.text,
    );
    if (success && mounted)
      Navigator.pushNamedAndRemoveUntil(context, '/signed-in', (_) => false);
  }

  Future<void> _resend() async {
    await context.read<AuthCubit>().resendRegistrationCode(widget.email);
  }

  @override
  Widget build(BuildContext context) => AuthShell(
    icon: Icons.mark_email_read_outlined,
    title: 'Verify your email',
    subtitle:
        'Enter the six-digit code sent to ${widget.email}. The code expires in 15 minutes.',
    form: AuthFormCard(
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthTextField(
                label: 'Verification code',
                controller: _code,
                hintText: '000000',
                icon: Icons.password_outlined,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                validator: (value) =>
                    RegExp(r'^\d{6}$').hasMatch(value?.trim() ?? '')
                    ? null
                    : 'Enter the six-digit code from your email.',
                onChanged: (_) => context.read<AuthCubit>().clearMessage(),
              ),
              const SizedBox(height: 18),
              AuthActionButton(label: 'Verify email', onPressed: _verify),
            ],
          ),
        ),
        const SizedBox(height: 10),
        TextButton(onPressed: _resend, child: const Text('Send a new code')),
      ],
    ),
    footer: TextButton.icon(
      onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
      icon: const Icon(Icons.arrow_back, size: 16),
      label: const Text('Back to log in'),
    ),
  );
}
