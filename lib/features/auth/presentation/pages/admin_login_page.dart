import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_cubit.dart';
import '../validators/auth_validators.dart';
import '../widgets/auth_action_button.dart';
import '../widgets/auth_footer.dart';
import '../widgets/auth_form_card.dart';
import '../widgets/auth_shell.dart';
import '../widgets/auth_text_field.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState!.validate()) {
      final success = await context.read<AuthCubit>().login(
        _email.text,
        _password.text,
        admin: true,
      );
      if (success && mounted)
        Navigator.pushReplacementNamed(context, '/signed-in');
    }
  }

  @override
  Widget build(BuildContext context) => AuthShell(
    icon: Icons.login,
    title: 'Admin sign-in',
    subtitle: 'Sign in with your administrator account to manage Z8.',
    form: AuthFormCard(
      showGoogle: true,
      googleAdminOnly: true,
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthTextField(
                label: 'Email',
                controller: _email,
                hintText: 'you@example.com',
                icon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: AuthValidators.email,
                onChanged: (_) => context.read<AuthCubit>().clearMessage(),
              ),
              const SizedBox(height: 18),
              AuthTextField(
                label: 'Password',
                controller: _password,
                hintText: '••••••••',
                icon: Icons.lock_outline,
                isPassword: true,
                textInputAction: TextInputAction.done,
                validator: AuthValidators.loginPassword,
                onChanged: (_) => context.read<AuthCubit>().clearMessage(),
              ),
              const SizedBox(height: 16),
              AuthActionButton(label: 'Log in', onPressed: _submit),
            ],
          ),
        ),
      ],
    ),
    footer: AuthFooter(
      prompt: 'Looking for your cards?',
      action: 'User sign-in',
      onPressed: () => Navigator.pushNamed(context, '/login'),
    ),
  );
}
