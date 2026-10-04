import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/transaction_model.dart';
import '../../services/firestore_service.dart';
import 'add_transaction_page.dart';

class TransactionDetailsPage extends StatefulWidget {
  final TransactionModel transaction;
  final String categoryName;
  final String accountName;

  const TransactionDetailsPage({
    super.key,
    required this.transaction,
    required this.categoryName,
    required this.accountName,
  });

  @override
  State<TransactionDetailsPage> createState() => _TransactionDetailsPageState();
}

class _TransactionDetailsPageState extends State<TransactionDetailsPage> {
  static const background = Color(0xFF0B0F14);
  static const card = Color(0xFF171D24);
  static const textPrimary = Color(0xFFE5E7EB);
  static const textSecondary = Color(0xFF9CA3AF);
  static const accent = Color(0xFF2DD4A7);
  static const error = Color(0xFFF87171);

  bool deleting = false;

  Future<void> _edit() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddTransactionPage(
          transactionType: widget.transaction.type,
          editTransaction: widget.transaction,
        ),
      ),
    );
    if (updated == true && mounted) Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: card,
        title: const Text(
          'Delete transaction?',
          style: TextStyle(color: textPrimary),
        ),
        content: const Text(
          'Are you sure you want to delete this transaction? The account balance will be updated.',
          style: TextStyle(color: textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: error)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => deleting = true);
    try {
      await FirestoreService.instance.deleteTransaction(widget.transaction.id!);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to delete transaction: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = widget.transaction.type == 'income';
    final color = isIncome ? accent : error;
    final amount = NumberFormat('#,##0.00').format(widget.transaction.amount);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        foregroundColor: textPrimary,
        title: const Text('Transaction Details'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 36, 24, 120),
              children: [
                Icon(
                  isIncome ? Icons.check_circle : Icons.arrow_downward_rounded,
                  color: color,
                  size: 82,
                ),
                const SizedBox(height: 24),
                Text(
                  '${isIncome ? '+' : '-'} Rs $amount',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isIncome ? 'Income' : 'Expense',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 32),
                _detail('Category', widget.categoryName),
                _detail('Payment Method', widget.accountName),
                _detail('Date', widget.transaction.date),
                _detail('Time', widget.transaction.time),
                if (widget.transaction.note != null &&
                    widget.transaction.note!.isNotEmpty)
                  _detail('Note', widget.transaction.note!),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: deleting ? null : _edit,
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: background,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: deleting ? null : _delete,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: error,
                        side: const BorderSide(color: error),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF26303A))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(child: Text('')),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: textSecondary, fontSize: 16),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
