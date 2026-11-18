import 'package:flutter/material.dart';

class NamCinemaColors {
  const NamCinemaColors._();

  static const Color primaryBackground = Color(0xFF08090D);
  static const Color secondaryBackground = Color(0xFF12141B);
  static const Color surface = Color(0xFF1A1D26);
  static const Color primaryAccent = Color(0xFFE50935);
  static const Color secondaryAccent = Color(0xFF7C4DFF);
  static const Color primaryText = Color(0xFFFFFFFF);
  static const Color secondaryText = Color(0xFFA1A1AA);
  static const Color divider = Color(0xFF272A33);
  static const Color playableBadge = Color(0xFF10B981);
  static const Color externalBadge = Color(0xFF3B82F6);
  static const Color warning = Color(0xFFF59E0B);
}

class NamCinemaTheme {
  const NamCinemaTheme._();

  static ThemeData get darkTheme {
    const colorScheme = ColorScheme.dark(
      primary: NamCinemaColors.primaryAccent,
      secondary: NamCinemaColors.secondaryAccent,
      surface: NamCinemaColors.surface,
      error: Color(0xFFEF4444),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: NamCinemaColors.primaryText,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: NamCinemaColors.primaryBackground,
      colorScheme: colorScheme,
      dividerColor: NamCinemaColors.divider,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: NamCinemaColors.primaryText,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: NamCinemaColors.primaryText),
      ),
      cardTheme: CardTheme(
        color: NamCinemaColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: NamCinemaColors.divider, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: NamCinemaColors.secondaryBackground,
        hintStyle: const TextStyle(color: NamCinemaColors.secondaryText),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: NamCinemaColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: NamCinemaColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: NamCinemaColors.primaryAccent,
            width: 1.5,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: NamCinemaColors.surface,
        selectedColor: NamCinemaColors.primaryAccent,
        side: const BorderSide(color: NamCinemaColors.divider),
        labelStyle: const TextStyle(
          color: NamCinemaColors.primaryText,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: NamCinemaColors.primaryText,
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          color: NamCinemaColors.primaryText,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleLarge: TextStyle(
          color: NamCinemaColors.primaryText,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: NamCinemaColors.primaryText,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: NamCinemaColors.primaryText,
          fontSize: 15,
          height: 1.45,
        ),
        bodyMedium: TextStyle(
          color: NamCinemaColors.secondaryText,
          fontSize: 13.5,
          height: 1.45,
        ),
      ),
    );
  }
}
