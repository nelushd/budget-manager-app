import 'package:intl/intl.dart';

/// Currency formatting for every amount the app renders.
///
/// The code itself comes from the account the amount belongs to
/// (`AccountModel.currency`, stored per account in Firestore) — this file only
/// turns that code into a symbol and lays the number out. Nothing here decides
/// *which* currency the user is in.

/// Used only when an account has no currency stored on it, matching the
/// default in [AccountModel].
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

/// Symbol for [currencyCode], falling back to the code itself so an
/// unrecognised currency still renders as 'AED 1,200.00' rather than a bare
/// number with no unit.
String currencySymbol(String currencyCode) {
  final code = currencyCode.trim().toUpperCase();
  if (code.isEmpty) return _currencySymbols[fallbackCurrencyCode]!;
  return _currencySymbols[code] ?? code;
}

/// 'Rs. 1,234.56' — amounts shown on their own: balances, totals, list rows.
String formatCurrency(
  double amount, {
  String currency = fallbackCurrencyCode,
}) {
  final formatted = NumberFormat('#,##0.00').format(amount);
  return '${currencySymbol(currency)} $formatted';
}

/// 'Rs. 1235' — amounts embedded mid-sentence in insight text, where cents
/// are noise.
String formatCurrencyWhole(
  double amount, {
  String currency = fallbackCurrencyCode,
}) {
  return '${currencySymbol(currency)} ${amount.toStringAsFixed(0)}';
}