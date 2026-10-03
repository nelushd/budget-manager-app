import 'package:intl/intl.dart';

const String fallbackCurrencyCode = 'LKR';

const Map<String, String> _currencySymbols = {
  'LKR': 'Rs.',
  'USD': '\$',
  'EUR': '€',
  'GBP': '£',
  'INR': '₹',
  'AUD': 'A\$',
  'CAD': 'C\$',
  'SGD': 'S\$',
  'JPY': '¥',
};


String currencySymbol(String currencyCode) {
  final code = currencyCode.trim().toUpperCase();
  if (code.isEmpty) return _currencySymbols[fallbackCurrencyCode]!;
  return _currencySymbols[code] ?? code;
}

String formatCurrency(
  double amount, {
  String currency = fallbackCurrencyCode,
}) {
  final formatted = NumberFormat('#,##0.00').format(amount);
  return '${currencySymbol(currency)} $formatted';
}

String formatCurrencyWhole(
  double amount, {
  String currency = fallbackCurrencyCode,
}) {
  return '${currencySymbol(currency)} ${amount.toStringAsFixed(0)}';
}