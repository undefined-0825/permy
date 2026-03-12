import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:sample_app/core/theme/app_colors.dart';
import 'package:sample_app/core/theme/app_radius.dart';
import 'package:sample_app/core/theme/app_spacing.dart';
import 'package:sample_app/core/theme/app_text_styles.dart';

/// Permy用Theme定義
class AppTheme {
  static ThemeData get lightTheme {
    final ThemeData baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryPink,
        secondary: AppColors.secondaryPink,
        error: AppColors.error,
        surface: Colors.white,
        onPrimary: AppColors.white,
        onSecondary: AppColors.white,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.primaryTitle),
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryTitle,
          letterSpacing: 0.1,
        ),
      ),

      textTheme: const TextTheme(
        headlineLarge: AppTextStyles.primaryTitle,
        titleLarge: AppTextStyles.primaryTitle,
        headlineSmall: AppTextStyles.sectionHeader,
        bodyLarge: AppTextStyles.body,
        bodySmall: AppTextStyles.meta,
        bodyMedium: AppTextStyles.small,
        labelLarge: AppTextStyles.buttonLabel,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryPink,
          foregroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryPink,
          side: const BorderSide(color: AppColors.primaryPink),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryPink,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
        ),
      ),

      inputDecorationTheme: const InputDecorationTheme(
        contentPadding: EdgeInsets.symmetric(
          horizontal: 0,
          vertical: AppSpacing.inputVertical,
        ),
        border: UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.separator),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.primaryPink, width: 2),
        ),
        labelStyle: AppTextStyles.body,
        hintStyle: AppTextStyles.meta,
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.primaryTitle),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.separator,
        thickness: 0.5,
        space: AppSpacing.md,
      ),

      scaffoldBackgroundColor: Colors.transparent,
      splashColor: AppColors.highlight,
      highlightColor: AppColors.highlight,
      hoverColor: AppColors.highlight,
    );

    return baseTheme.copyWith(
      textTheme: GoogleFonts.notoSansJpTextTheme(baseTheme.textTheme),
      primaryTextTheme: GoogleFonts.notoSansJpTextTheme(
        baseTheme.primaryTextTheme,
      ),
      hoverColor: AppColors.highlight.withOpacity(0.5),
    );
  }
}
