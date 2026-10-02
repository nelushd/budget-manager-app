import 'package:flutter/material.dart';

/// Deterministic accent color per category, derived from the category's id.
/// Categories don't store a color today — this keeps budget UI colorful
/// without touching CategoryModel or existing Firestore category docs.
const List<Color> _categoryPalette = [
  Color(0xFF0F766E), // teal
  Color(0xFF22C55E), // emerald
  Color(0xFFF59E0B), // amber
  Color(0xFF6366F1), // indigo
  Color(0xFFEF4444), // coral
  Color(0xFF06B6D4), // cyan
  Color(0xFF8B5CF6), // violet
  Color(0xFFEC4899), // pink
  Color(0xFFF97316), // orange
  Color(0xFF14B8A6), // teal light
];

Color colorForCategory(String? categoryId) {
  if (categoryId == null || categoryId.isEmpty) {
    return _categoryPalette.first;
  }

  final hash = categoryId.codeUnits.fold<int>(0, (sum, c) => sum + c);
  return _categoryPalette[hash % _categoryPalette.length];
}
