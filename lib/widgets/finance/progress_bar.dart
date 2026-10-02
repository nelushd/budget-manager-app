import 'package:flutter/material.dart';

import '../../constants/colors.dart';

class FinanceProgressBar extends StatelessWidget {
  final double value;
  final double max;
  final Color? color;
  final bool thin;

  const FinanceProgressBar({
    super.key,
    required this.value,
    required this.max,
    this.color,
    this.thin = false,
  });

  @override
  Widget build(BuildContext context) {
    final pct = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    final isOver = value > max;
    final isWarn = !isOver && (max <= 0 ? false : (value / max) > 0.84);

    final barColor = isOver
        ? AppColors.error
        : isWarn
            ? AppColors.warning
            : (color ?? AppColors.primary);

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: pct,
        minHeight: thin ? 4 : 8,
        backgroundColor: const Color(0xFFF1F5F9),
        valueColor: AlwaysStoppedAnimation<Color>(barColor),
      ),
    );
  }
}
