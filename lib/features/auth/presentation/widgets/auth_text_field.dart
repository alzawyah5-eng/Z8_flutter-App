import 'package:flutter/material.dart';

class AuthTextField extends StatefulWidget {
  const AuthTextField({
    required this.label,
    required this.icon,
    required this.validator,
    this.controller,
    this.hintText,
    this.keyboardType,
    this.textInputAction,
    this.isPassword = false,
    this.showLabel = true,
    this.onChanged,
    super.key,
  });

  final String label;
  final IconData icon;
  final String? Function(String?) validator;
  final TextEditingController? controller;
  final String? hintText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool isPassword;
  final bool showLabel;
  final ValueChanged<String>? onChanged;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showLabel) ...[
          Text(
            widget.label,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          autovalidateMode: AutovalidateMode.disabled,
          controller: widget.controller,
          validator: widget.validator,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          obscureText: widget.isPassword && _obscureText,
          style: const TextStyle(fontSize: 14),
          autocorrect: false,
          enableSuggestions: !widget.isPassword,
          onChanged: widget.onChanged,
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon: Icon(widget.icon, size: 19),
            suffixIcon: widget.isPassword
                ? IconButton(
                    tooltip: _obscureText ? 'Show password' : 'Hide password',
                    onPressed: () =>
                        setState(() => _obscureText = !_obscureText),
                    icon: Icon(
                      _obscureText
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 19,
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
