const List<String> recurringFrequencies = [
  'daily',
  'weekly',
  'biweekly',
  'monthly',
  'quarterly',
  'yearly',
];

String frequencyLabel(String frequency) {
  switch (frequency) {
    case 'biweekly':
      return 'Bi-weekly';
    default:
      if (frequency.isEmpty) return frequency;
      return frequency[0].toUpperCase() + frequency.substring(1);
  }
}

DateTime advanceDate(DateTime date, String frequency) {
  switch (frequency) {
    case 'daily':
      return date.add(const Duration(days: 1));
    case 'weekly':
      return date.add(const Duration(days: 7));
    case 'biweekly':
      return date.add(const Duration(days: 14));
    case 'quarterly':
      return DateTime(date.year, date.month + 3, date.day);
    case 'yearly':
      return DateTime(date.year + 1, date.month, date.day);
    case 'monthly':
    default:
      return DateTime(date.year, date.month + 1, date.day);
  }
}
