import 'package:flutter/material.dart';

class ReceiptScanResult {
  final String rawText;
  final double? amount;
  final String? title;
  final String? category;
  final DateTime? date;
  final TimeOfDay? time;
  final String? notes;

  const ReceiptScanResult({
    required this.rawText,
    this.amount,
    this.title,
    this.category,
    this.date,
    this.time,
    this.notes,
  });
}