import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../utils/calculator.dart';

class _KeypadDark {
  _KeypadDark._();
  static const Color sheetBg = Color(0xFF141B24);
  static const Color displayBg = Color(0xFF1B2430);
  static const Color keyBg = Color(0xFF1B2430);
  static const Color divider = Color(0xFF2E3A4A);
  static const Color accent = Color(0xFF2DD4A7);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF9CA3AF);
}


Future<void> showCalculatorKeypad(
  BuildContext context, {
  required TextEditingController controller,
  String currency = 'Rs',
  bool dark = false,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: dark ? _KeypadDark.sheetBg : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _CalculatorKeypadSheet(controller: controller, currency: currency, dark: dark),
  );

  final finalValue = evaluateExpression(controller.text);
  controller.text = finalValue != null ? formatAmount(finalValue) : '';
}

class _CalculatorKeypadSheet extends StatefulWidget {
  final TextEditingController controller;
  final String currency;
  final bool dark;

  const _CalculatorKeypadSheet({required this.controller, required this.currency, required this.dark});

  @override
  State<_CalculatorKeypadSheet> createState() => _CalculatorKeypadSheetState();
}

class _CalculatorKeypadSheetState extends State<_CalculatorKeypadSheet> {
  late String _expression;

  bool get _dark => widget.dark;

  @override
  void initState() {
    super.initState();
    _expression = widget.controller.text;
  }

  String get _lastSegment {
    final match = RegExp(r'[^+−×÷]*$').firstMatch(_expression);
    return match?.group(0) ?? '';
  }

  void _update(String next) {
    setState(() => _expression = next);
    widget.controller.text = next;
  }

  void _tapDigit(String digit) {
    _update(_expression + digit);
  }

  void _tapDecimal() {
    if (_lastSegment.contains('.')) return;
    _update(_expression + (_lastSegment.isEmpty ? '0.' : '.'));
  }

  void _tapOperator(String op) {
    if (_expression.isEmpty) return;
    final last = _expression[_expression.length - 1];
    if ('+−×÷'.contains(last)) {
      _update(_expression.substring(0, _expression.length - 1) + op);
    } else {
      _update(_expression + op);
    }
  }

  void _backspace() {
    if (_expression.isEmpty) return;
    _update(_expression.substring(0, _expression.length - 1));
  }

  void _done() {
    Navigator.pop(context);
  }

  double? get _preview => evaluateExpression(_expression);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: _dark ? _KeypadDark.divider : Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: _dark ? _KeypadDark.displayBg : Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: _dark ? Border.all(color: _KeypadDark.divider) : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${widget.currency} ${_expression.isEmpty ? '0' : _expression}',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: _dark ? _KeypadDark.textPrimary : Colors.black,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  if (_preview != null && _expression.contains(RegExp(r'[+−×÷]')))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '= ${formatAmount(_preview!)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: _dark ? _KeypadDark.textSecondary : Colors.grey[500],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _row(['7', '8', '9', '÷']),
            const SizedBox(height: 10),
            _row(['4', '5', '6', '×']),
            const SizedBox(height: 10),
            _row(['1', '2', '3', '−']),
            const SizedBox(height: 10),
            _row(['.', '0', '⌫', '+']),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _done,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _dark ? _KeypadDark.accent : AppColors.primary,
                  foregroundColor: _dark ? const Color(0xFF06231C) : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(List<String> keys) {
    return Row(
      children: keys.map((key) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _key(key),
          ),
        );
      }).toList(),
    );
  }

  Widget _key(String key) {
    final isOperator = '+−×÷'.contains(key);
    final isBackspace = key == '⌫';

    final accentColor = _dark ? _KeypadDark.accent : AppColors.primary;
    final keyBg = _dark ? _KeypadDark.keyBg : Colors.grey[100];
    final textColor = _dark ? _KeypadDark.textPrimary : Colors.black87;

    return Material(
      color: isOperator ? accentColor.withValues(alpha: _dark ? 0.16 : 0.10) : keyBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          if (isBackspace) {
            _backspace();
          } else if (key == '.') {
            _tapDecimal();
          } else if (isOperator) {
            _tapOperator(key);
          } else {
            _tapDigit(key);
          }
        },
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: _dark && !isOperator
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _KeypadDark.divider),
                )
              : null,
          child: isBackspace
              ? Icon(Icons.backspace_outlined, size: 20, color: textColor)
              : Text(
                  key,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isOperator ? accentColor : textColor,
                  ),
                ),
        ),
      ),
    );
  }
}
