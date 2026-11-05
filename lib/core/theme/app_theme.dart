import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const plum = Color(0xFF74144F);
  static const plumDark = Color(0xFF35122E);
  static const ink = Color(0xFF17243B);
  static const muted = Color(0xFF68758A);
  static const canvas = Color(0xFFF8F8FA);
  static const border = Color(0xFFDDE0E8);
  static const fieldFill = Color(0xFFF0F2FC);
  static const mint = Color(0xFFD9EFDE);

  static ThemeData get light {
    const colors = ColorScheme.light(
      primary: plum,
      onPrimary: Colors.white,
      secondary: ink,
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: ink,
      error: Color(0xFFB42348),
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: canvas,
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: ink,
          fontSize: 34,
          height: 1.12,
          fontWeight: FontWeight.w600,
          letterSpacing: -1.1,
        ),
        bodyMedium: TextStyle(color: muted, fontSize: 14, height: 1.5),
        labelLarge: TextStyle(fontWeight: FontWeight.w600),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        hintStyle: const TextStyle(color: muted),
        prefixIconColor: muted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: plum, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFB42348)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFB42348), width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: plum,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
