import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ペルミィ デザイン定義 (design_rule.md 準拠)
/// - Modern Seamless & Breathable コンセプト
/// - Edge-less Flat デザイン
/// - カラーパレット・タイポグラフィの統一管理

class PermyColors {
  // 背景グラデーション
  static const Color backgroundStart = Color(0xFFE8D4F8); // 淡いパープル
  static const Color backgroundEnd = Color(0xFFFCE4EC); // 淡いピンク

  // アクセントカラー
  static const Color primaryPink = Color(0xFFFFB3C1); // プライマリピンク
  static const Color secondaryPink = Color(0xFFFF69B4); // セカンダリピンク
  static const Color lightPink = Color(0xFFFCE7F3); // 淡ピンク
  static const Color disabledPink = Color(0xFFE6DCE8); // 淡いグレイピンク

  // テキストカラー
  static const Color primaryTitle = Color(0xFF1A1C1E); // プライマリタイトル
  static const Color bodyText = Color(0xFF374151); // 本文
  static const Color metaText = Color(0xFF6B7280); // メタ情報
  static const Color white = Color(0xFFFFFFFF); // ボタンラベル

  // セパレーター
  static const Color separator = Color(0xFFE5E7EB); // セパレーター極細ライン
  static const Color highlight = Color(0xFFF3F4F6); // ハイライト背景

  // エラー
  static const Color error = Color(0xFFEF4444); // エラーメッセージ
}

class PermyTypography {
  // プライマリタイトル: 18pt Bold
  static const TextStyle primaryTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: PermyColors.primaryTitle,
    height: 1.35,
  );

  // 本文: 15pt Regular（読み疲れを抑えるため軽め）
  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: PermyColors.bodyText,
    height: 1.7,
  );

  // メタ情報: 13pt Regular（本文より一段弱め）
  static const TextStyle meta = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: PermyColors.metaText,
    height: 1.55,
  );

  // アクセント数値: 20pt Semi-bold
  static const TextStyle accentNumber = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: PermyColors.primaryPink,
    height: 1.2,
  );

  // セクションヘッダー: 16pt Bold
  static const TextStyle sectionHeader = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: PermyColors.primaryTitle,
  );

  // ボタンラベル: 15pt SemiBold（短時間での判読性を優先）
  static const TextStyle buttonLabel = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: PermyColors.white,
  );

  // Small: 12pt Regular (補助テキスト)
  static const TextStyle small = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: PermyColors.metaText,
  );
}

class PermyTheme {
  static ThemeData get lightTheme {
    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: PermyColors.primaryPink,
        secondary: PermyColors.secondaryPink,
        error: PermyColors.error,
        surface: Colors.white,
        onPrimary: PermyColors.white,
        onSecondary: PermyColors.white,
      ),

      // AppBar (Standard)
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: PermyColors.primaryTitle),
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: PermyColors.primaryTitle,
          letterSpacing: 0.1,
        ),
      ),

      // Text Theme
      textTheme: TextTheme(
        headlineLarge: PermyTypography.primaryTitle,
        titleLarge: PermyTypography.primaryTitle,
        headlineSmall: PermyTypography.sectionHeader,
        bodyLarge: PermyTypography.body,
        bodySmall: PermyTypography.meta,
        bodyMedium: PermyTypography.small,
        labelLarge: PermyTypography.buttonLabel,
      ),

      // Elevated Button (Primary) - PrimaryButtonウィジェットで置き換え推奨
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: PermyColors.primaryPink,
          foregroundColor: PermyColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),

      // Outlined Button (Secondary)
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: PermyColors.primaryPink,
          side: const BorderSide(color: PermyColors.primaryPink),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),

      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: PermyColors.primaryPink,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),

      // TextField
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
        border: const UnderlineInputBorder(
          borderSide: BorderSide(color: PermyColors.separator),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: PermyColors.primaryPink, width: 2),
        ),
        labelStyle: PermyTypography.body,
        hintStyle: PermyTypography.meta,
      ),

      // IconButton
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: PermyColors.primaryTitle),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: PermyColors.separator,
        thickness: 0.5,
        space: 16,
      ),

      // Scaffold Background
      scaffoldBackgroundColor: Colors.transparent,

      // Material タップ時のハイライト
      splashColor: PermyColors.highlight,
      highlightColor: PermyColors.highlight,
      hoverColor: PermyColors.highlight.withOpacity(0.5),
    );

    return baseTheme.copyWith(
      textTheme: GoogleFonts.notoSansJpTextTheme(baseTheme.textTheme),
      primaryTextTheme: GoogleFonts.notoSansJpTextTheme(
        baseTheme.primaryTextTheme,
      ),
    );
  }
}
