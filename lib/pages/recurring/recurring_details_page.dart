import 'package:flutter/material.dart';

import '../../constants/colors.dart';
import '../../models/category_model.dart';
import '../../models/recurring_expense_model.dart';
import '../../models/recurring_payment_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/category_icon.dart';
import '../../utils/frequency.dart';
import '../../utils/period_calculator.dart';
import '../../utils/recurring_status.dart';
import '../../widgets/finance/finance_widgets.dart';
import 'add_recurring_page.dart';

class RecurringDetailsPage extends StatefulWidget {
  final String expenseId;

  const RecurringDetailsPage({super.key, required this.expenseId});

  @override
  State<RecurringDetailsPage> createState() => _RecurringDetailsPageState();
}

class _RecurringDetailsPageState extends State<RecurringDetailsPage> {
  final FirestoreService _firestoreService = FirestoreService.instance;

  bool isLoading = true;
  RecurringExpenseModel? expense;
  CategoryModel? category;
  List<RecurringPaymentModel> payments = [];
  bool isRecording = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => isLoading = true);
    try {
      final loadedExpense = await _firestoreService.getRecurringExpenseById(widget.expenseId);
      if (loadedExpense == null) {
        if (!mounted) return;
        setState(() {
          expense = null;
          isLoading = false;
        });
        return;
      }

      final loadedCategory = await _firestoreService.getCategoryById(loadedExpense.categoryId);
      final loadedPayments = await _firestoreService.getRecurringPayments(widget.expenseId);

      if (!mounted) return;
      setState(() {
        expense = loadedExpense;
        category = loadedCategory;
        payments = loadedPayments;
        isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Error loading recurring details: $error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> _recordPayment() async {
    setState(() => isRecording = true);
    try {
      await _firestoreService.markRecurringPaid(widget.expenseId);
      await _load();
    } catch (error, stackTrace) {
      debugPrint('Error recording payment: $error');
      debugPrint('$stackTrace');
    } finally {
      if (mounted) setState(() => isRecording = false);
    }
  }

  Future<void> _confirmDelete() async {
    final e = expense;
    if (e?.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete "${e!.name}"?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _firestoreService.deleteRecurringExpense(e!.id!);
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _edit() async {
    final e = expense;
    if (e == null) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddRecurringPage(existing: e)),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final e = expense;

    if (isLoading && e == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }
    if (e == null) {
      return const Scaffold(body: Center(child: Text('Expense not found')));
    }

    final today = PeriodCalculator.formatDate(DateTime.now());
    final paidToday = payments.any((p) => p.paymentDate == today);
    final status = computeRecurringStatus(nextDueDate: e.nextDueDate, paidToday: paidToday);
    final totalPaid = payments.where((p) => p.status == 'paid').fold<double>(0, (s, p) => s + p.amount);
    final missed = payments.where((p) => p.status == 'missed').length;
    final isOverdue = status == 'overdue';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(e.name),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: _edit),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isOverdue
                    ? [AppColors.error, const Color(0xFFDC2626)]
                    : [const Color(0xFF1E293B), const Color(0xFF334155)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                      child: Icon(
                        category != null ? getCategoryIcon(category!.iconName) : Icons.autorenew,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${category?.name ?? 'Uncategorized'} · ${frequencyLabel(e.frequency)}',
                            style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                          Text(e.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                    StatusBadge(label: recurringStatusLabel(status), color: Colors.white),
                  ],
                ),
                const SizedBox(height: 18),
                Text('Rs ${e.amount.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800)),
                Text('per ${frequencyLabel(e.frequency).toLowerCase()}', style: const TextStyle(color: Colors.white60)),
                if (e.reminderDays > 0) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.notifications_outlined, color: Colors.white70, size: 16),
                        const SizedBox(width: 6),
                        Text('Reminder ${e.reminderDays} day${e.reminderDays == 1 ? '' : 's'} before',
                            style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.4,
            children: [
              _statCard('Next Due', e.nextDueDate, Icons.event),
              _statCard('Frequency', frequencyLabel(e.frequency), Icons.autorenew),
              _statCard('Total Paid', 'Rs ${totalPaid.toStringAsFixed(0)}', Icons.check_circle_outline),
              _statCard('Missed', missed == 0 ? 'None' : '$missed', Icons.error_outline, warn: missed > 0),
            ],
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.play_circle_outline, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 8),
                Text('Start Date', style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(
                  e.startDate,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PrimaryActionButton(
            label: isRecording ? 'Recording...' : 'Record Payment',
            icon: Icons.check,
            onPressed: isRecording ? null : _recordPayment,
          ),
          if (payments.isNotEmpty) ...[
            const SizedBox(height: 20),
            const SectionLabel('Payment History'),
            ...payments.map((p) {
              final isPaid = p.status == 'paid';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: (isPaid ? AppColors.secondary : AppColors.error).withValues(alpha: 0.12),
                      child: Icon(isPaid ? Icons.check : Icons.close, size: 14, color: isPaid ? AppColors.secondaryDark : AppColors.error),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.paymentDate, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text(p.status, style: TextStyle(fontSize: 11, color: isPaid ? AppColors.secondaryDark : AppColors.error)),
                        ],
                      ),
                    ),
                    Text('Rs ${p.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, {bool warn = false}) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: warn ? AppColors.error : AppColors.textPrimary),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
