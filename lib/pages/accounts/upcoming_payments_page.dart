import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/account_model.dart';

const _bg = Color(0xFF0B0F14);
const _card = Color(0xFF141B24);
const _accent = Color(0xFF2DD4A7);
const _textPrimary = Colors.white;
const _textSecondary = Color(0xFF9CA3AF);

class UpcomingPaymentsPage extends StatelessWidget {
  final AccountModel card;

  const UpcomingPaymentsPage({super.key, required this.card});

  DateTime _dayInMonth(int year, int month, int day) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, day > lastDay ? lastDay : day);
  }

  DateTime? get _nextDueDate {
    final dueDay = card.dueDay;
    if (dueDay == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var candidate = _dayInMonth(now.year, now.month, dueDay);
    if (candidate.isBefore(today)) {
      final nextMonth = DateTime(now.year, now.month + 1, 1);
      candidate = _dayInMonth(nextMonth.year, nextMonth.month, dueDay);
    }
    return candidate;
  }

  @override
  Widget build(BuildContext context) {
    final dueDate = _nextDueDate;
    final hasPaymentDue = card.balance > 0 && dueDate != null;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: _textPrimary,
        elevation: 0,
        title: const Text('Upcoming Payments', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: hasPaymentDue ? _paymentDueCard(dueDate) : _emptyState(),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _accent, width: 2),
              ),
              child: const Icon(Icons.check, color: _accent, size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              "No upcoming payments — you're all caught up!",
              textAlign: TextAlign.center,
              style: TextStyle(color: _textSecondary, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentDueCard(DateTime dueDate) {
    final daysLeft = dueDate.difference(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)).inDays;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: _accent.withValues(alpha: 0.14), shape: BoxShape.circle),
                  child: const Icon(Icons.credit_card, color: _accent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(card.name, style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
                      Text(
                        'Due ${DateFormat('MMM d, yyyy').format(dueDate)} · $daysLeft day${daysLeft == 1 ? '' : 's'} left',
                        style: const TextStyle(color: _textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Rs ${NumberFormat('#,##0.00').format(card.balance)}',
              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const Text('Amount due', style: TextStyle(color: _textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
