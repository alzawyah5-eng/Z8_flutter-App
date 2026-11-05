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

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState!.validate()) {
      await context.read<AuthCubit>().resetPassword(_email.text);
    }
  }

  @override
  Widget build(BuildContext context) => AuthShell(
    icon: Icons.mail_outline,
    title: 'Reset password',
    subtitle: "We'll send you a link to reset it.",
    form: AuthFormCard(
      children: [
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
                textInputAction: TextInputAction.done,
                validator: AuthValidators.email,
                onChanged: (_) => context.read<AuthCubit>().clearMessage(),
              ),
              const SizedBox(height: 16),
              AuthActionButton(label: 'Send reset link', onPressed: _submit),
            ],
          ),
        ),
      ],
    ),
    footer: TextButton.icon(
      onPressed: () => Navigator.pushNamed(context, '/login'),
      icon: const Icon(Icons.arrow_back, size: 16),
      label: const Text('Back to log in'),
    ),
  );
}
