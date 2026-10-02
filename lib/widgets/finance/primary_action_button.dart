import 'package:flutter/material.dart';

import '../../constants/colors.dart';

enum ActionButtonVariant { primary, secondary, ghost, danger }

class PrimaryActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final ActionButtonVariant variant;
  final IconData? icon;

  const PrimaryActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = ActionButtonVariant.primary,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    late final Color background;
    late final Color foreground;
    Border? border;

    switch (variant) {
      case ActionButtonVariant.primary:
        background = AppColors.primary;
        foreground = Colors.white;
        break;
      case ActionButtonVariant.secondary:
        background = AppColors.primary.withValues(alpha: 0.10);
        foreground = AppColors.primary;
        break;
      case ActionButtonVariant.ghost:
        background = Colors.transparent;
        foreground = AppColors.textSecondary;
        border = Border.all(color: AppColors.divider);
        break;
      case ActionButtonVariant.danger:
        background = AppColors.error.withValues(alpha: 0.10);
        foreground = AppColors.error;
        break;
    }

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: border,
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: foreground),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: onPressed == null
                        ? foreground.withValues(alpha: 0.4)
                        : foreground,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
