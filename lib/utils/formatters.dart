import 'package:intl/intl.dart';

class Formatters {
  // Format currency
  static String formatCurrency(double amount) {
    final formatter = NumberFormat.currency(symbol: '\$');
    return formatter.format(amount);
  }

  // Format date
  static String formatDate(DateTime date) {
    final formatter = DateFormat('MMM dd, yyyy');
    return formatter.format(date);
  }

  // Format date with time
  static String formatDateTime(DateTime dateTime) {
    final formatter = DateFormat('MMM dd, yyyy - hh:mm a');
    return formatter.format(dateTime);
  }

  // Format date for display
  static String formatDateShort(DateTime date) {
    final formatter = DateFormat('MM/dd/yy');
    return formatter.format(date);
  }

  // Format percentage
  static String formatPercentage(double percentage) {
    return '${percentage.toStringAsFixed(2)}%';
  }

  // Parse currency string
  static double parseCurrency(String currencyString) {
    final cleaned = currencyString.replaceAll(RegExp(r'[^\d.-]'), '');
    return double.parse(cleaned);
  }
}
