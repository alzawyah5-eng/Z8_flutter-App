import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_cubit.dart';
import '../validators/auth_validators.dart';
import '../widgets/auth_action_button.dart';
import '../widgets/auth_form_card.dart';
import '../widgets/auth_shell.dart';
import '../widgets/auth_text_field.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _token = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _hasResetLink = false;
  bool _requestSent = false;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      final fragment = Uri.tryParse(Uri.base.fragment);
      final query = {...Uri.base.queryParameters, ...?fragment?.queryParameters};
      final email = query['email'];
      final token = query['token'];
      if (email != null && token != null && token.length >= 40) {
        _email.text = email;
        _token.text = token;
        _hasResetLink = true;
      }
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _token.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthCubit>();
    if (!_hasResetLink) {
      await auth.requestPasswordReset(_email.text);
      if (mounted && auth.state.message == null) setState(() => _requestSent = true);
      return;
    }
    await auth.confirmPasswordReset(
      email: _email.text,
      token: _token.text,
      password: _password.text,
    );
    if (mounted && auth.state.message == 'Your password has been reset. You can now sign in.') {
      setState(() => _completed = true);
    }
  }

  @override
  Widget build(BuildContext context) => AuthShell(
    icon: Icons.mail_outline,
    title: _completed
        ? 'Password updated'
        : _hasResetLink
        ? 'Choose a new password'
        : _requestSent
        ? 'Check your email'
        : 'Reset password',
    subtitle: _completed
        ? 'Your new password is ready to use.'
        : _hasResetLink
        ? 'Your secure reset link is valid for one hour. Choose and confirm a new password below.'
        : _requestSent
        ? 'If an account exists for this email, a reset link has been sent. The link expires in one hour.'
        : "We'll email a one-hour reset link if an account exists for that address.",
    form: AuthFormCard(
      children: [
        if (!_completed && !_requestSent)
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthTextField(
                  label: 'Email address',
                  controller: _email,
                  hintText: 'you@example.com',
                  icon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: _hasResetLink ? TextInputAction.next : TextInputAction.done,
                  validator: AuthValidators.email,
                  onChanged: (_) => context.read<AuthCubit>().clearMessage(),
                ),
                if (_hasResetLink) ...[
                  const SizedBox(height: 16),
                  AuthTextField(
                    label: 'New password',
                    controller: _password,
                    hintText: 'At least 8 characters',
                    icon: Icons.lock_outline,
                    isPassword: true,
                    textInputAction: TextInputAction.next,
                    validator: AuthValidators.password,
                    onChanged: (_) => context.read<AuthCubit>().clearMessage(),
                  ),
                  const SizedBox(height: 16),
                  AuthTextField(
                    label: 'Confirm new password',
                    controller: _confirmation,
                    hintText: 'Re-enter new password',
                    icon: Icons.lock_outline,
                    isPassword: true,
                    textInputAction: TextInputAction.done,
                    validator: (value) => value == _password.text
                        ? null
                        : 'The passwords do not match.',
                    onChanged: (_) => context.read<AuthCubit>().clearMessage(),
                  ),
                ],
                const SizedBox(height: 16),
                AuthActionButton(
                  label: _hasResetLink ? 'Save new password' : 'Email reset link',
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        if (_completed)
          AuthActionButton(
            label: 'Back to log in',
            onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
          ),
      ],
    ),
    footer: TextButton.icon(
      onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
      icon: const Icon(Icons.arrow_back, size: 16),
      label: const Text('Back to log in'),
    ),
  );
}
