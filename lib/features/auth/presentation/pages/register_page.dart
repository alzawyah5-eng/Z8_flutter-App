import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_cubit.dart';
import '../validators/auth_validators.dart';
import '../widgets/auth_action_button.dart';
import '../widgets/auth_footer.dart';
import '../widgets/auth_form_card.dart';
import '../widgets/auth_shell.dart';
import '../widgets/auth_text_field.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState!.validate()) {
      final success = await context.read<AuthCubit>().register(
        _email.text,
        _password.text,
      );
      if (success && mounted)
        Navigator.pushReplacementNamed(context, '/signed-in');
      if (!success && mounted) {
        final email = context.read<AuthCubit>().state.registrationEmail;
        if (email != null)
          Navigator.pushNamed(context, '/verify-email', arguments: email);
      }
    }
  }

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthShell(
    icon: Icons.person_add_alt_1_outlined,
    title: 'Create your account',
    subtitle: 'A simpler way to keep your cards together starts here.',
    form: AuthFormCard(
      showGoogle: true,
      children: [
        Form(
          autovalidateMode: AutovalidateMode.disabled,
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
                icon: Icons.lock_outline,
                isPassword: true,
                controller: _password,
                hintText: '••••••••',
                textInputAction: TextInputAction.next,
                validator: AuthValidators.password,
                onChanged: (_) => context.read<AuthCubit>().clearMessage(),
              ),
              const SizedBox(height: 18),
              AuthTextField(
                label: 'Confirm password',
                icon: Icons.lock_outline,
                isPassword: true,
                controller: _confirmation,
                hintText: '••••••••',
                textInputAction: TextInputAction.done,
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Confirm your password.';
                  if (value != _password.text) return 'Passwords do not match.';
                  return null;
                },
                onChanged: (_) => context.read<AuthCubit>().clearMessage(),
              ),
              const SizedBox(height: 18),
              AuthActionButton(label: 'Create account', onPressed: _submit),
            ],
          ),
        ),
      ],
    ),
    footer: AuthFooter(
      prompt: 'Already have an account?',
      action: 'Log in',
      onPressed: () => Navigator.pushNamed(context, '/login'),
    ),
  );
}
