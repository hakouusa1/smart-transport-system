import 'package:flutter/material.dart';

class AppTheme {
  // ============================================
  // COLORS
  // ============================================
  static const Color primary = Color(0xFF0066FF);
  static const Color primaryDark = Color(0xFF0044CC);
  static const Color primaryLight = Color(0xFF3D8BFF);
  static const Color accent = Color(0xFF00D68F);
  static const Color accentDark = Color(0xFF00B377);

  static const Color background = Color(0xFFF5F7FB);
  static const Color surface = Colors.white;
  static const Color dark = Color(0xFF1A1F36);
  static const Color darkGrey = Color(0xFF4A5568);
  static const Color mediumGrey = Color(0xFF8896AB);
  static const Color lightGrey = Color(0xFFE2E8F0);

  static const Color success = Color(0xFF00D68F);
  static const Color warning = Color(0xFFFFAA00);
  static const Color error = Color(0xFFFF3D71);
  static const Color info = Color(0xFF0095FF);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0066FF), Color(0xFF5B8DEF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF1A1F36), Color(0xFF2D3555)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF00D68F), Color(0xFF00B377)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ============================================
  // THEME DATA
  // ============================================
  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        fontFamily: 'Poppins',
        brightness: Brightness.light,
        scaffoldBackgroundColor: background,
        colorSchemeSeed: primary,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: dark,
          titleTextStyle: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: dark,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: lightGrey),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: lightGrey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: error),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          hintStyle: TextStyle(color: mediumGrey, fontSize: 14),
          labelStyle: TextStyle(color: darkGrey, fontSize: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 54),
            backgroundColor: primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 54),
            side: const BorderSide(color: primary, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.white,
        ),
      );

  // ============================================
  // SHADOWS
  // ============================================
  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get mediumShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 30,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get coloredShadow => [
        BoxShadow(
          color: primary.withValues(alpha: 0.3),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];
}
