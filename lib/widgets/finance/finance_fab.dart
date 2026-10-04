import 'package:flutter/material.dart';
import '../../constants/colors.dart';

class FinanceFab extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData icon;

  const FinanceFab({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.add,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      icon: Icon(icon),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}
