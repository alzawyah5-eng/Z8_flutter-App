import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_cubit.dart';
import '../validators/auth_validators.dart';
import '../widgets/auth_action_button.dart';
import '../widgets/auth_footer.dart';
import '../widgets/auth_form_card.dart';
import '../widgets/auth_shell.dart';
import '../widgets/auth_text_field.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
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
    if (!_formKey.currentState!.validate()) return;
    final success = await context.read<AuthCubit>().login(_email.text, _password.text);
    if (success && mounted) Navigator.pushReplacementNamed(context, '/signed-in');
  }

  @override
  Widget build(BuildContext context) => AuthShell(
    icon: Icons.login,
    title: 'Welcome back',
    subtitle: 'Your card workspace is ready when you are.',
    form: AuthFormCard(
      showGoogle: true,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Password', style: TextStyle(fontWeight: FontWeight.w500)),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/forgot-password'),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                    child: const Text('Forgot password?', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              AuthTextField(
                label: 'Password',
                controller: _password,
                hintText: '••••••••',
                icon: Icons.lock_outline,
                isPassword: true,
                showLabel: false,
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
    footer: Column(
      children: [
        AuthFooter(
          prompt: "Don't have an account?",
          action: 'Create one',
          onPressed: () => Navigator.pushNamed(context, '/register'),
        ),
        TextButton(
          onPressed: () => Navigator.pushNamed(context, '/admin/login'),
          child: const Text('Admin sign-in'),
        ),
      ],
    ),
  );
}
