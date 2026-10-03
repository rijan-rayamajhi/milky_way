import 'package:flutter/material.dart';

/// Milky Way cosmic palette. Centralized so every screen reads as one system.
class AppColors {
  static const navy = Color(0xFF0B0B2B);
  static const deepPurple = Color(0xFF1A0B3D);
  static const purple = Color(0xFF6A2DB5);
  static const magenta = Color(0xFFE040FB);
  static const teal = Color(0xFF26E0D8);
  static const gold = Color(0xFFFFC73B);
  static const goldDark = Color(0xFFE59A00);
  static const textDim = Color(0xFFB9B4D6);

  static const bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [navy, deepPurple, Color(0xFF0B0B2B)],
  );

  static const goldGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [gold, goldDark],
  );
}

class AppTheme {
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.navy,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.gold,
          secondary: AppColors.teal,
          surface: AppColors.deepPurple,
        ),
        fontFamily: 'Roboto',
      );
}
