import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Brand Colors (Solid Vibrant ZiRa Blue #2C7BE5)
  static const Color primary = Color(0xFF2C7BE5);
  static const Color primaryLight = Color(0xFF2C7BE5);
  static const Color primaryDark = Color(0xFF2C7BE5); // Keep solid vibrant #2C7BE5 in dark mode
  static const Color primaryAccent = Color(0xFF1A58B0);
  static const Color linkDark = Color(0xFF6EA8FE);
  static const Color accent = Color(0xFFF97316);

  // Status Colors (Identical to Web)
  static const Color success = Color(0xFF22C55E);
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF0EA5E9);

  // Light Palette
  static const Color bgLight = Color(0xFFF5F6FA);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color topbarLight = Color(0xFFFFFFFF);
  static const Color bottomnavLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE8ECF1);
  static const Color textMainLight = Color(0xFF1E293B);
  static const Color textMutedLight = Color(0xFF8695A0);
  static const Color inputBgLight = Color(0xFFF8FAFC);
  static const Color avatarBgLight = Color(0xFFE8ECF1);
  static const Color avatarTextLight = Color(0xFF5E6870);

  // Dark Palette (100% Identical to Web CSS)
  static const Color bgDark = Color(0xFF16181B);
  static const Color cardDark = Color(0xFF1E2024);
  static const Color topbarDark = Color(0xFF1E2024);
  static const Color bottomnavDark = Color(0xFF1E2024);
  static const Color borderDark = Color(0xFF2C3035);
  static const Color textMainDark = Color(0xFFF8F9FA);
  static const Color textMutedDark = Color(0xFF8B95A5);
  static const Color inputBgDark = Color(0xFF262A2E);
  static const Color avatarBgDark = Color(0xFF2C3035);
  static const Color avatarTextDark = Color(0xFFABB2BF);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.bgLight,
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.cardLight,
        background: AppColors.bgLight,
        error: AppColors.danger,
      ),
      cardTheme: CardTheme(
        color: AppColors.cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
      ),
      textTheme: GoogleFonts.poppinsTextTheme().apply(
        bodyColor: AppColors.textMainLight,
        displayColor: AppColors.textMainLight,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.topbarLight,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.bgDark,
      colorScheme: ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.cardDark,
        background: AppColors.bgDark,
        error: AppColors.danger,
      ),
      cardTheme: CardTheme(
        color: AppColors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderDark, width: 1),
        ),
      ),
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: AppColors.textMainDark,
        displayColor: AppColors.textMainDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.topbarDark,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
    );
  }
}
