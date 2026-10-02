import 'package:flutter/material.dart';

import 'calculator_keypad.dart';

/// Labeled amount input. Tapping it opens the calculator-style keypad
/// (digits plus +, -, ×, ÷) instead of the system keyboard, used for every
/// amount field across the app.
class AmountField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String prefix;
  final String hint;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  const AmountField({
    super.key,
    required this.label,
    required this.controller,
    this.prefix = 'Rs',
    this.hint = '0.00',
    this.autofocus = false,
    this.onChanged,
  });

  Future<void> _openKeypad(BuildContext context) async {
    await showCalculatorKeypad(context, controller: controller, currency: prefix);
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
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 6),
        ],
        Material(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openKeypad(context),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 14),
                    child: Text(
                      prefix,
                      style: TextStyle(
                        color: Colors.grey[500],
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
                              color: hasValue ? Colors.black87 : Colors.grey[400],
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
