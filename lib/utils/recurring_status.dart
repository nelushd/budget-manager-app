import 'package:flutter/material.dart';
import '../constants/colors.dart';
import 'period_calculator.dart';


String computeRecurringStatus({
  required String nextDueDate,
  required bool paidToday,
}) {
  if (paidToday) return 'paid';
  if (nextDueDate.isEmpty) return 'upcoming';

  final due = PeriodCalculator.parseDate(nextDueDate);
  final dueEnd = DateTime(due.year, due.month, due.day, 23, 59, 59);

  if (DateTime.now().isAfter(dueEnd)) return 'overdue';
  return 'upcoming';
}

String recurringStatusLabel(String status) {
  switch (status) {
    case 'overdue':
      return 'Overdue';
    case 'paid':
      return 'Paid';
    case 'upcoming':
    default:
      return 'Upcoming';
  }
}

Color recurringStatusColor(String status) {
  switch (status) {
    case 'overdue':
      return AppColors.error;
    case 'paid':
      return AppColors.secondary;
    case 'upcoming':
    default:
      return AppColors.warning;
  }
}
