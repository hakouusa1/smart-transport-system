  import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PALETTE — all raw color values live here, nowhere else.
// ─────────────────────────────────────────────────────────────────────────────

// Neutrals — light
const _lightBg        = Color(0xFFF5F5F5);
const _lightSurface   = Color(0xFFFFFFFF);
const _lightSurface2  = Color(0xFFF0F0F0);
const _lightBorder    = Color(0xFFE0E0E0);
const _lightTextPri   = Color(0xFF1A1A1A);
const _lightTextSec   = Color(0xFF757575);

// Neutrals — dark
const _darkBg         = Color(0xFF121212);
const _darkSurface    = Color(0xFF1E1E1E);
const _darkSurface2   = Color(0xFF252525);
const _darkSurface3   = Color(0xFF2C2C2C);
const _darkBorder     = Color(0xFF2E2E2E);
const _darkTextPri    = Color(0xFFE1E3E6);
const _darkTextSec    = Color(0xFF9DA3A9);

// Accent
const _accentBlueLt   = Color(0xFF1565C0);
const _accentBlueDk   = Color(0xFF1154A8);
const _accentPurpleLt = Color(0xFF7C3AED);
const _accentPurpleDk = Color(0xFF6B34D4);

// Semantics
const _greenLt        = Color(0xFF2E7D32);
const _greenDk        = Color(0xFF28713A);
const _redLt          = Color(0xFFD32F2F);
const _redDk          = Color(0xFFB52929);
const _orangeLt       = Color(0xFFF57C00);
const _orangeDk       = Color(0xFFCC6900);
const _tealLt         = Color(0xFF00B0FF);
const _tealDk         = Color(0xFF0096D6);

// ─────────────────────────────────────────────────────────────────────────────
// APP THEME
// ─────────────────────────────────────────────────────────────────────────────
abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark()  => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final isDark = b == Brightness.dark;

    final colorScheme = isDark
        ? ColorScheme.dark(
            surface:                     _darkSurface,
            surfaceContainerHighest:     _darkSurface2,
            primary:                     _accentBlueDk,
            secondary:                   _accentPurpleDk,
            onSurface:                   _darkTextPri,
            onSurfaceVariant:            _darkTextSec,
            outline:                     _darkBorder,
            error:                       _redDk,
          )
        : ColorScheme.light(
            surface:                     _lightSurface,
            surfaceContainerHighest:     _lightSurface2,
            primary:                     _accentBlueLt,
            secondary:                   _accentPurpleLt,
            onSurface:                   _lightTextPri,
            onSurfaceVariant:            _lightTextSec,
            outline:                     _lightBorder,
            error:                       _redLt,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark ? _darkBg : _lightBg,

      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? _darkBg : _lightBg,
        foregroundColor: isDark ? _darkTextPri : _lightTextPri,
      ),

      cardTheme: CardThemeData(
        color: isDark ? _darkSurface : _lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? _darkBorder : _lightBorder,
            width: 1,
          ),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: isDark ? _darkBorder : _lightBorder,
        thickness: 1,
      ),

      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: isDark ? _darkSurface2 : _lightSurface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: isDark ? _darkTextSec : _lightTextSec),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? _accentBlueDk : _accentBlueLt,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: isDark ? _darkSurface2 : _lightSurface,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor:  isDark ? _darkSurface  : _lightSurface,
        surfaceTintColor: Colors.transparent,
        indicatorColor:   isDark
            ? _accentPurpleDk.withValues(alpha: 0.20)
            : _accentPurpleLt.withValues(alpha: 0.15),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? (isDark ? _accentPurpleDk : _accentPurpleLt)
                : (isDark ? _darkTextSec    : _lightTextSec),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? (isDark ? _accentPurpleDk : _accentPurpleLt)
                : (isDark ? _darkTextSec    : _lightTextSec),
            size: selected ? 26 : 24,
          );
        }),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? _darkSurface : _lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      textTheme: TextTheme(
        headlineMedium: TextStyle(
            fontWeight: FontWeight.w700,
            color: isDark ? _darkTextPri : _lightTextPri),
        bodyMedium: TextStyle(color: isDark ? _darkTextPri : _lightTextPri),
        bodySmall:  TextStyle(color: isDark ? _darkTextSec : _lightTextSec),
        labelSmall: TextStyle(color: isDark ? _darkTextSec : _lightTextSec),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// THEME NOTIFIER
// ─────────────────────────────────────────────────────────────────────────────
class ThemeNotifier extends ValueNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('themeMode');
    value = stored == 'dark'
        ? ThemeMode.dark
        : stored == 'light'
            ? ThemeMode.light
            : ThemeMode.system;
  }

  Future<void> setMode(ThemeMode mode) async {
    value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode.name);
  }

  Future<void> toggleTheme() async {
    await setMode(value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }
}

final themeNotifier = ThemeNotifier();

// ─────────────────────────────────────────────────────────────────────────────
// THEME COLORS EXTENSION — semantic tokens consumed by all widgets
// ─────────────────────────────────────────────────────────────────────────────
extension ThemeColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  // Surfaces
  Color get appBg       => isDark ? _darkBg       : _lightBg;
  Color get appCardBg   => isDark ? _darkSurface   : _lightSurface;
  Color get appCardBg2  => isDark ? _darkSurface2  : _lightSurface2;
  Color get appCardBg3  => isDark ? _darkSurface3  : const Color(0xFFE8E8E8);

  // Text
  Color get appDark     => isDark ? _darkTextPri  : _lightTextPri;
  Color get appText     => isDark ? _darkTextPri  : _lightTextPri;
  Color get appSub      => isDark ? _darkTextSec  : _lightTextSec;

  // Borders
  Color get appBorder   => isDark ? _darkBorder   : _lightBorder;

  // Brand accents
  Color get appPrimary      => isDark ? _accentBlueDk   : _accentBlueLt;
  Color get appPrimaryDark  => isDark ? const Color(0xFF0A3D80) : const Color(0xFF0D47A1);
  Color get appPrimaryLight => isDark ? const Color(0xFF1A6BC4) : const Color(0xFF1976D2);
  Color get appPurple       => isDark ? _accentPurpleDk : _accentPurpleLt;
  Color get appAccent       => isDark ? _tealDk         : _tealLt;

  // Semantics
  Color get appGreen      => isDark ? _greenDk  : _greenLt;
  Color get appGreenLight => isDark ? const Color(0xFF3EA84A) : const Color(0xFF4CAF50);
  Color get appRed        => isDark ? _redDk    : _redLt;
  Color get appOrange     => isDark ? _orangeDk : _orangeLt;

  // Legacy aliases
  Color get appNavy      => appPrimary;
  Color get appLightBlue => appAccent;
  Color get appSoftGray  => isDark ? _darkSurface2 : const Color(0xFFF5F5F5);
}
