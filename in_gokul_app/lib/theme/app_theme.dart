import 'package:flutter/material.dart';

class AppColors {
  // ── Cream White Palette ──────────────────────────────────────────────────
  static const Color creamBg = Color(0xFFF9F7F2);        // Warm luxury cream background
  static const Color creamSurface = Color(0xFFFFFFFF);   // Pure crisp surface
  static const Color creamSurfaceAlt = Color(0xFFF3EFE6); // Warmer secondary container
  static const Color creamBorder = Color(0xFFE5DFD3);     // Subtle cream border
  static const Color creamBorderLight = Color(0xFFF0EBE1);

  // ── Blue Palette ─────────────────────────────────────────────────────────
  static const Color primaryBlue = Color(0xFF1E40AF);     // Royal / Cobalt Blue
  static const Color accentBlue = Color(0xFF2563EB);      // Electric Blue
  static const Color lightBlue = Color(0xFF3B82F6);       // Sky Accent
  static const Color vibrantBlue = Color(0xFF0284C7);     // Ocean Blue
  static const Color softBlue = Color(0xFFEFF6FF);        // Soft blue container tint
  static const Color softBlueBorder = Color(0xFFBFDBFE);  // Soft blue border
  static const Color navyDark = Color(0xFF0F172A);        // Deep Midnight Navy

  // ── Text Palette ─────────────────────────────────────────────────────────
  static const Color textDark = Color(0xFF0F172A);        // Deep charcoal-navy text
  static const Color textMuted = Color(0xFF475569);       // Slate grey text
  static const Color textSubtle = Color(0xFF94A3B8);      // Light grey subtitle
  static const Color textLight = Color(0xFFFAF8F5);       // Cream white on dark

  // ── Status Colors ────────────────────────────────────────────────────────
  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFDC2626);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.creamBg,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryBlue,
        secondary: AppColors.accentBlue,
        surface: AppColors.creamSurface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.creamBg,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textDark,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.creamSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.creamBorder, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: AppColors.textDark,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(
          color: AppColors.textDark,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: TextStyle(
          color: AppColors.textDark,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(color: AppColors.textDark),
        bodyMedium: TextStyle(color: AppColors.textMuted),
        bodySmall: TextStyle(color: AppColors.textSubtle),
      ),
    );
  }
}
