import 'package:flutter/material.dart';

class AppColors {
  // Primary (teal)
  static const Color primary = Color(0xFF0F766E);
  static const Color primaryDark = Color(0xFF115E59);
  static const Color primaryLight = Color(0xFF14B8A6);

  // Secondary (emerald) — income / positive / on-track
  static const Color secondary = Color(0xFF22C55E);
  static const Color secondaryDark = Color(0xFF15803D);
  static const Color secondaryLight = Color(0xFF86EFAC);

  // Status colors
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF0EA5E9);

  // Neutral
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color divider = Color(0xFFE5E7EB);

  // Gradients (summary cards / hero sections)
  static const List<Color> primaryGradient = [
    Color(0xFF115E59),
    Color(0xFF0F766E),
    Color(0xFF14B8A6),
  ];

  static const List<Color> secondaryGradient = [
    Color(0xFF15803D),
    Color(0xFF22C55E),
    Color(0xFF4ADE80),
  ];
}
