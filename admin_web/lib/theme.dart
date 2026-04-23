import 'package:flutter/material.dart';

// Project palette: #021024, #052659, #5483B3, #7DA0CA, #C1E8FF
class AppColors {
  static const deepNavy = Color(0xFF021024);
  static const navy = Color(0xFF052659);
  static const blue = Color(0xFF5483B3);
  static const lightBlue = Color(0xFF7DA0CA);
  static const ice = Color(0xFFC1E8FF);

  static const bg = Color(0xFFF4F7FA);
  static const card = Colors.white;
  static const dark = Color(0xFF1A1D2B);
  static const text = Color(0xFF2D3142);
  static const sub = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);

  static const green = Color(0xFF059669);
  static const red = Color(0xFFDC2626);
  static const orange = Color(0xFFF59E0B);
  static const purple = Color(0xFF7C3AED);
}

class AppTheme {
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    colorSchemeSeed: AppColors.navy,
    scaffoldBackgroundColor: AppColors.bg,
    fontFamily: 'Inter',
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.deepNavy,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
  );
}
