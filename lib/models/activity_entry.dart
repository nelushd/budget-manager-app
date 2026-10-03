import 'package:flutter/material.dart';

class ActivityEntry {
  final String title;
  final String subtitle;
  final String? note;
  final double amount;
  final bool isInflow;
  final String kind; // income | expense | loan | lending
  final DateTime date;
  final String accountName;
  final IconData icon;

  const ActivityEntry({
    required this.title,
    required this.subtitle,
    this.note,
    required this.amount,
    required this.isInflow,
    required this.kind,
    required this.date,
    required this.accountName,
    required this.icon,
  });
}
