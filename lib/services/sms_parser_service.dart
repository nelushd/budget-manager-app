import 'package:flutter/material.dart';

class ParsedSms {
  final String type; 
  final double amount;
  final String currency;
  final DateTime? date;
  final TimeOfDay? time;

  const ParsedSms({
    required this.type,
    required this.amount,
    required this.currency,
    this.date,
    this.time,
  });
}

const List<String> _creditKeywords = [
  'credited',
  'credit',
  'received',
  'deposited',
  'deposit',
];
const List<String> _debitKeywords = [
  'debited',
  'debit',
  'withdrawn',
  'withdrawal',
  'spent',
  'purchase',
  'paid',
  'payment of',
];
final RegExp _fromAccountPattern = RegExp(r'\bfrom\s+a\s*/?\s*c\b', caseSensitive: false);
final RegExp _toAccountPattern = RegExp(r'\bto\s+a\s*/?\s*c\b', caseSensitive: false);

final RegExp _labeledAmountPattern = RegExp(
  r'amount\s*(?:\(approx\.?\))?\s*[:.]?\s*([0-9][0-9,]*\.?[0-9]{0,2})',
  caseSensitive: false,
);

final RegExp _currencyAmountPattern = RegExp(
  r'(rs\.?|lkr|inr|usd|\$)\s*([0-9][0-9,]*\.?[0-9]{0,2})',
  caseSensitive: false,
);

final RegExp _suffixCurrencyAmountPattern = RegExp(
  r'\b([0-9][0-9,]*\.[0-9]{2})\s*(?:lkr|rs\.?|inr|usd)\b',
  caseSensitive: false,
);

final RegExp _decimalAmountPattern = RegExp(r'\b\d{1,3}(?:,\d{3})*\.\d{2}\b');

const Map<String, int> _monthAbbreviations = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
  'jul': 7, 'aug': 8, 'sep': 9, 'sept': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};

final RegExp _monthNameDatePattern = RegExp(
  r'\b(\d{1,2})\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\s+(\d{4})\b',
  caseSensitive: false,
);
final RegExp _isoDatePattern = RegExp(r'\b(\d{4})-(\d{1,2})-(\d{1,2})\b');

ParsedSms? parseSmsText(String body) {
  final lower = body.toLowerCase();

  bool isCredit = _creditKeywords.any(lower.contains);
  bool isDebit = _debitKeywords.any(lower.contains);


  if (!isCredit && !isDebit) {
    if (_fromAccountPattern.hasMatch(lower)) {
      isDebit = true;
    } else if (_toAccountPattern.hasMatch(lower)) {
      isCredit = true;
    }
  }
  if (!isCredit && !isDebit) return null;

  final amount = _extractAmount(body);
  if (amount == null || amount <= 0) return null;

  return ParsedSms(
    type: isDebit ? 'debit' : 'credit',
    amount: amount,
    currency: _extractCurrency(body),
    date: _extractSmsDate(body),
    time: _extractSmsTime(body),
  );
}

double? _extractAmount(String text) {
  final labeledMatch = _labeledAmountPattern.firstMatch(text);
  if (labeledMatch != null) {
    final raw = labeledMatch.group(1);
    if (raw != null && raw.isNotEmpty) {
      final parsed = double.tryParse(raw.replaceAll(',', ''));
      if (parsed != null) return parsed;
    }
  }

  final currencyMatch = _currencyAmountPattern.firstMatch(text);
  if (currencyMatch != null) {
    final raw = currencyMatch.group(2);
    if (raw != null && raw.isNotEmpty) {
      final parsed = double.tryParse(raw.replaceAll(',', ''));
      if (parsed != null) return parsed;
    }
  }

  final suffixMatch = _suffixCurrencyAmountPattern.firstMatch(text);
  if (suffixMatch != null) {
    final raw = suffixMatch.group(1);
    if (raw != null && raw.isNotEmpty) {
      final parsed = double.tryParse(raw.replaceAll(',', ''));
      if (parsed != null) return parsed;
    }
  }

  final decimalMatch = _decimalAmountPattern.firstMatch(text);
  if (decimalMatch != null) {
    return double.tryParse(decimalMatch.group(0)!.replaceAll(',', ''));
  }

  return null;
}

String _extractCurrency(String text) {
  final match = _currencyAmountPattern.firstMatch(text);
  final code = match?.group(1)?.toUpperCase().replaceAll('.', '');
  if (code == null) return 'LKR';
  if (code.startsWith('RS')) return 'LKR';
  if (code == r'$') return 'USD';
  return code;
}


DateTime? _extractSmsDate(String text) {
  final isoMatch = _isoDatePattern.firstMatch(text);
  if (isoMatch != null) {
    final date = _buildValidDate(
      year: int.parse(isoMatch.group(1)!),
      month: int.parse(isoMatch.group(2)!),
      day: int.parse(isoMatch.group(3)!),
    );
    if (date != null) return date;
  }

  final monthNameMatch = _monthNameDatePattern.firstMatch(text);
  if (monthNameMatch != null) {
    final month = _monthAbbreviations[monthNameMatch.group(2)!.toLowerCase()];
    if (month != null) {
      final date = _buildValidDate(
        year: int.parse(monthNameMatch.group(3)!),
        month: month,
        day: int.parse(monthNameMatch.group(1)!),
      );
      if (date != null) return date;
    }
  }

  final RegExp pattern = RegExp(r'\b(\d{1,2})[./-](\d{1,2})[./-](\d{2,4})\b');
  final RegExpMatch? match = pattern.firstMatch(text);
  if (match == null) return null;

  final String yearRaw = match.group(3)!;
  int year = int.parse(yearRaw);
  if (yearRaw.length == 2) year += 2000;

  return _buildValidDate(
    year: year,
    month: int.parse(match.group(2)!),
    day: int.parse(match.group(1)!),
  );
}

DateTime? _buildValidDate({required int year, required int month, required int day}) {
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;

  final DateTime date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    return null;
  }

  return date;
}

TimeOfDay? _extractSmsTime(String text) {
  final RegExp pattern = RegExp(r'\b([01]?\d|2[0-3]):([0-5]\d)(?::[0-5]\d)?\b');
  final RegExpMatch? match = pattern.firstMatch(text);
  if (match == null) return null;

  return TimeOfDay(
    hour: int.parse(match.group(1)!),
    minute: int.parse(match.group(2)!),
  );
}
