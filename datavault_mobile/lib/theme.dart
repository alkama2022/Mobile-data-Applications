import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Light palette
  static const background = Color(0xFFF2F5FA);
  static const foreground = Color(0xFF20293B);
  static const card = Colors.white;
  static const primary = Color(0xFF2F6FED);
  static const primarySoft = Color(0xFFE6EEFC);
  static const muted = Color(0xFFEEF1F7);
  static const mutedForeground = Color(0xFF5B657D);
  static const border = Color(0xFFDDE3EE);
  static const input = Color(0xFFD4DBE8);
  static const highlight = Color(0xFFF0B429);
  static const highlightForeground = Color(0xFF3D2F10);
  static const highlightSoft = Color(0xFFF9ECD2);
  static const brand = Color(0xFF141C33);
  static const brandElevated = Color(0xFF232C4A);
  static const success = Color(0xFF2E9E77);
  static const successSoft = Color(0xFFE3F4EC);
  static const destructive = Color(0xFFD94F3D);
  static const destructiveForeground = Colors.white;
  static const accent = Color(0xFFCFE9F0);
  static const accentForeground = Color(0xFF2C4A5C);

  // Dark palette equivalents
  static const darkBackground = Color(0xFF0F1623);
  static const darkCard = Color(0xFF1A2235);
  static const darkBorder = Color(0xFF283047);
  static const darkInput = Color(0xFF2E3A52);
  static const darkMuted = Color(0xFF1E2A3A);
  static const darkMutedForeground = Color(0xFF8A9AB8);
  static const darkForeground = Color(0xFFE8EDF5);
}

TextStyle displayStyle({double size = 22, FontWeight weight = FontWeight.w700, Color? color}) =>
    GoogleFonts.sora(fontSize: size, fontWeight: weight, color: color ?? AppColors.foreground);

TextStyle displayStyleDark({double size = 22, FontWeight weight = FontWeight.w700, Color? color}) =>
    GoogleFonts.sora(fontSize: size, fontWeight: weight, color: color ?? AppColors.darkForeground);

TextStyle displayStyleOf(BuildContext context, {double size = 22, FontWeight weight = FontWeight.w700, Color? color}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return GoogleFonts.sora(fontSize: size, fontWeight: weight, color: color ?? (dark ? AppColors.darkForeground : AppColors.foreground));
}

/// Customer-friendly helpers: always use these instead of raw AppColors.card/border
/// so dark mode stays consistent.
Color cardColorOf(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? AppColors.darkCard : AppColors.card;

Color borderColorOf(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? AppColors.darkBorder : AppColors.border;

Color mutedColorOf(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? AppColors.darkMutedForeground : AppColors.mutedForeground;

ThemeData buildTheme({bool dark = false}) {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: GoogleFonts.manrope().fontFamily,
    brightness: dark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: dark ? AppColors.darkBackground : AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: dark ? Brightness.dark : Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      surface: dark ? AppColors.darkCard : AppColors.card,
      onSurface: dark ? AppColors.darkForeground : AppColors.foreground,
    ),
  );
  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? AppColors.darkBackground : AppColors.background,
      foregroundColor: dark ? AppColors.darkForeground : AppColors.foreground,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: dark ? AppColors.darkCard : AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: dark ? AppColors.darkBorder : AppColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      fillColor: dark ? AppColors.darkCard : AppColors.card,
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: dark ? AppColors.darkInput : AppColors.input),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: dark ? AppColors.darkInput : AppColors.input),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? AppColors.darkCard : AppColors.card,
      indicatorColor: AppColors.primarySoft,
    ),
    dividerColor: dark ? AppColors.darkBorder : AppColors.border,
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.primary : null),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.primarySoft : null),
    ),
  );
}

