import 'package:flutter/material.dart';
import 'calculator_keypad.dart';



class FinanceDark {
  FinanceDark._();
  static const Color bg = Color(0xFF0B0F14);
  static const Color card = Color(0xFF19212C);
  static const Color accent = Color(0xFF2DD4A7);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color divider = Color(0xFF2A3441);
  static const Color success = Color(0xFF34D399);
  static const Color error = Color(0xFFF87171);
  static const Color warning = Color(0xFFFBBF24);
  static const Color info = Color(0xFF60A5FA);
}

class DarkCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;

  const DarkCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: FinanceDark.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor ?? FinanceDark.divider),
      ),
      child: child,
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

class DarkProgressBar extends StatelessWidget {
  final double value;
  final double max;
  final Color? color;
  final bool thin;

  const DarkProgressBar({
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
        ? FinanceDark.error
        : isWarn
            ? FinanceDark.warning
            : (color ?? FinanceDark.accent);

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: pct,
        minHeight: thin ? 4 : 8,
        backgroundColor: Colors.white12,
        valueColor: AlwaysStoppedAnimation<Color>(barColor),
      ),
    );
  }
}

class DarkEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const DarkEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: FinanceDark.accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: FinanceDark.accent),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: FinanceDark.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(color: FinanceDark.textSecondary, height: 1.4),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 22),
            DarkActionButton(label: actionLabel!, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}

class DarkSectionLabel extends StatelessWidget {
  final String text;

  const DarkSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
          color: FinanceDark.textSecondary,
        ),
      ),
    );
  }
}

enum DarkActionVariant { primary, secondary, ghost, danger }

class DarkActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final DarkActionVariant variant;
  final IconData? icon;

  const DarkActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = DarkActionVariant.primary,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    late final Color background;
    late final Color foreground;
    Border? border;

    switch (variant) {
      case DarkActionVariant.primary:
        background = FinanceDark.accent;
        foreground = FinanceDark.bg;
      case DarkActionVariant.secondary:
        background = FinanceDark.accent.withValues(alpha: 0.14);
        foreground = FinanceDark.accent;
      case DarkActionVariant.ghost:
        background = Colors.transparent;
        foreground = FinanceDark.textSecondary;
        border = Border.all(color: FinanceDark.divider);
      case DarkActionVariant.danger:
        background = FinanceDark.error.withValues(alpha: 0.14);
        foreground = FinanceDark.error;
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
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: border),
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
                    color: onPressed == null ? foreground.withValues(alpha: 0.4) : foreground,
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

/// A tappable "Rs ..." tile styled for dark pages, opening the same
/// calculator keypad sheet used everywhere else in the app.
class DarkAmountTile extends StatelessWidget {
  final TextEditingController controller;
  final String prefix;
  final String hint;
  final ValueChanged<String>? onChanged;

  const DarkAmountTile({
    super.key,
    required this.controller,
    this.prefix = 'Rs',
    this.hint = '0.00',
    this.onChanged,
  });

  Future<void> _openKeypad(BuildContext context) async {
    await showCalculatorKeypad(context, controller: controller, currency: prefix, dark: true);
    onChanged?.call(controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FinanceDark.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openKeypad(context),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: FinanceDark.divider),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 14),
                child: Text(
                  prefix,
                  style: const TextStyle(color: FinanceDark.textSecondary, fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                  child: AnimatedBuilder(
                    animation: controller,
                    builder: (context, _) {
                      final hasValue = controller.text.isNotEmpty;
                      return Text(
                        hasValue ? controller.text : hint,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: hasValue ? FinanceDark.textPrimary : FinanceDark.textSecondary,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
