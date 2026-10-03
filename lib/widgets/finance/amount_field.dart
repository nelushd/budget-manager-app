import 'package:flutter/material.dart';

import 'calculator_keypad.dart';
import 'dark_finance_widgets.dart';

class AmountField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String prefix;
  final String hint;
  final bool autofocus;
  final bool dark;
  final ValueChanged<String>? onChanged;

  const AmountField({
    super.key,
    required this.label,
    required this.controller,
    this.prefix = 'Rs',
    this.hint = '0.00',
    this.autofocus = false,
    this.dark = false,
    this.onChanged,
  });

  Future<void> _openKeypad(BuildContext context) async {
    await showCalculatorKeypad(context, controller: controller, currency: prefix, dark: dark);
    onChanged?.call(controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: dark ? FinanceDark.textSecondary : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 6),
        ],
        Material(
          color: dark ? FinanceDark.card : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openKeypad(context),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: dark ? FinanceDark.divider : Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 14),
                    child: Text(
                      prefix,
                      style: TextStyle(
                        color: dark ? FinanceDark.textSecondary : Colors.grey[500],
                        fontWeight: FontWeight.w700,
                      ),
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
                              color: hasValue ? (dark ? FinanceDark.textPrimary : Colors.black87) : (dark ? FinanceDark.textSecondary : Colors.grey[400]),
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
        ),
      ],
    );
  }
}
