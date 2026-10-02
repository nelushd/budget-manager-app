/// Evaluates a simple calculator expression like "500+250*2" (standard
/// precedence: * and / before + and -). Returns null if the expression is
/// empty, malformed, or divides by zero.
double? evaluateExpression(String rawExpression) {
  final expr = rawExpression
      .replaceAll('×', '*')
      .replaceAll('÷', '/')
      .replaceAll('−', '-')
      .trim();
  if (expr.isEmpty) return null;

  final tokens = <String>[];
  final buffer = StringBuffer();

  for (final char in expr.split('')) {
    if ('+-*/'.contains(char)) {
      if (buffer.isEmpty) continue; 
      tokens.add(buffer.toString());
      tokens.add(char);
      buffer.clear();
    } else {
      buffer.write(char);
    }
  }
  if (buffer.isNotEmpty) tokens.add(buffer.toString());
  if (tokens.isEmpty) return null;

  final firstNumber = double.tryParse(tokens.first);
  if (firstNumber == null) return null;

  final reduced = <String>[tokens.first];
  int i = 1;
  while (i < tokens.length - 1) {
    final op = tokens[i];
    final nextValue = double.tryParse(tokens[i + 1]);
    if (nextValue == null) return null;

    if (op == '*' || op == '/') {
      final prevValue = double.tryParse(reduced.removeLast());
      if (prevValue == null) return null;
      if (op == '/' && nextValue == 0) return null;
      final result = op == '*' ? prevValue * nextValue : prevValue / nextValue;
      reduced.add(result.toString());
    } else {
      reduced.add(op);
      reduced.add(tokens[i + 1]);
    }
    i += 2;
  }

  // Pass 2: resolve + and -.
  double? result = double.tryParse(reduced.first);
  if (result == null) return null;

  int j = 1;
  while (j < reduced.length - 1) {
    final op = reduced[j];
    final value = double.tryParse(reduced[j + 1]);
    if (value == null) return null;
    result = op == '+' ? result! + value : result! - value;
    j += 2;
  }

  if (result == null || result.isNaN || result.isInfinite) return null;
  return result;
}

/// Formats a computed amount the way the rest of the app does: whole
/// numbers with no decimals, otherwise up to 2 decimal places.
String formatAmount(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}
