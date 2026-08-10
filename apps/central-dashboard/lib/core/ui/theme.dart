import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static TextStyle _getTextStyle(
    TextStyle Function({
      TextStyle? textStyle,
      Color? color,
      double? fontSize,
      FontWeight? fontWeight,
      FontStyle? fontStyle,
    })
    googleFont, {
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
  }) {
    final isTest =
        const bool.fromEnvironment('INTEGRATION_TEST', defaultValue: false) ||
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (isTest) {
      return TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
      );
    }
    return googleFont(color: color, fontSize: fontSize, fontWeight: fontWeight);
  }

  // Theme colors
  static const Color background = Color(0xFF030303);
  static const Color cardBg = Color(0x12FFFFFF); // Frosted white transparency
  static const Color border = Color(0x1AFFFFFF); // 10% white border
  static const Color textPrimary = Color(0xFFF3F4F6);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color primary = Color(0xFF6366F1); // Indigo
  static const Color success = Color(0xFF10B981); // Emerald
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color error = Color(0xFFEF4444); // Red
  static const Color info = Color(0xFF3B82F6); // Blue

  // Status colors matching React project
  static const Map<String, Color> statusColors = {
    'new': Color(0xFF3B82F6), // Blue
    'assigned': Color(0xFF6366F1), // Indigo/Primary
    'in_progress': Color(0xFFF59E0B), // Warning/Amber
    'testing': Color(0xFF9333EA), // Purple
    'resolved': Color(0xFF10B981), // Success/Green
    'closed': Color(0xFF6B7280), // Muted Gray
  };

  static const Map<String, String> statusLabels = {
    'new': 'Nová',
    'assigned': 'Priradená',
    'in_progress': 'V riešení',
    'testing': 'Testovanie',
    'resolved': 'Vyriešená',
    'closed': 'Uzatvorená',
  };

  // Severity colors matching React project
  static const Map<String, Color> severityColors = {
    'critical': Color(0xFFEF4444), // Red
    'high': Color(0xFFF97316), // Orange
    'medium': Color(0xFFEAB308), // Yellow
    'low': Color(0xFF3B82F6), // Blue
  };

  static const Map<String, String> severityLabels = {
    'critical': 'Kritická',
    'high': 'Vysoká',
    'medium': 'Stredná',
    'low': 'Nízka',
  };

  // Glassmorphic Decoration
  static BoxDecoration glassDecoration({
    double borderRadius = 12.0,
    Color bgColor = const Color(0x0EFFFFFF),
    Color borderColor = const Color(0x15FFFFFF),
  }) {
    return BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: borderColor, width: 1.0),
    );
  }

  // Active / Selected Glassmorphic card
  static BoxDecoration activeGlassDecoration({double borderRadius = 12.0}) {
    return BoxDecoration(
      color: const Color(0x1AFFFFFF),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: const Color(0x33FFFFFF), width: 1.2),
    );
  }

  // Dark ThemeData
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: success,
        surface: background,
        error: error,
      ),
      textTheme: TextTheme(
        headlineLarge: _getTextStyle(
          GoogleFonts.outfit,
          color: textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: _getTextStyle(
          GoogleFonts.outfit,
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: _getTextStyle(
          GoogleFonts.outfit,
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: _getTextStyle(
          GoogleFonts.inter,
          color: textPrimary,
          fontSize: 14,
        ),
        bodyMedium: _getTextStyle(
          GoogleFonts.inter,
          color: textSecondary,
          fontSize: 13,
        ),
        labelLarge: _getTextStyle(
          GoogleFonts.inter,
          color: textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      dividerColor: border,
      cardTheme: CardThemeData(
        color: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
    );
  }
}
