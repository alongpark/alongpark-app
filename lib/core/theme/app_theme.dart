import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get dark => _build(Brightness.dark, AppColors.dark);
  static ThemeData get light => _build(Brightness.light, AppColors.light);

  static ThemeData _build(Brightness brightness, AppColors c) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: c.background,
      extensions: [c],

      colorScheme: ColorScheme(
        brightness: brightness,
        primary: AppColors.accent,
        onPrimary: isDark ? Colors.black : Colors.white,
        secondary: AppColors.primary,
        onSecondary: Colors.white,
        surface: c.surface,
        onSurface: c.textPrimary,
        error: AppColors.danger,
        onError: Colors.white,
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          color: c.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: c.textPrimary, size: 22),
      ),

      // Cards
      cardTheme: CardThemeData(
        elevation: 0,
        color: c.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // Filled button
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: isDark ? Colors.black : Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),

      // Outlined button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: c.border, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),

      // Text button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        hintStyle: TextStyle(color: c.textMuted, fontSize: 14),
      ),

      // Typography
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 34, fontWeight: FontWeight.w700,
          color: c.textPrimary, letterSpacing: -0.8,
        ),
        headlineLarge: TextStyle(
          fontSize: 28, fontWeight: FontWeight.w700,
          color: c.textPrimary, letterSpacing: -0.6,
        ),
        titleLarge: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w600,
          color: c.textPrimary, letterSpacing: -0.3,
        ),
        titleMedium: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w600,
          color: c.textPrimary, letterSpacing: -0.2,
        ),
        titleSmall: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w500,
          color: c.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w400,
          color: c.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w400,
          color: c.textSecondary,
        ),
        bodySmall: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w400,
          color: c.textMuted,
        ),
        labelLarge: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w500,
          color: c.textSecondary, letterSpacing: 0.1,
        ),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: c.border, thickness: 1, space: 1,
      ),

      // Bottom nav
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.surface,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: c.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // Linear progress
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
      ),
    );
  }
}
