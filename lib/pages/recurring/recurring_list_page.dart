import 'package:flutter/material.dart';

import '../../constants/colors.dart';
import '../../models/category_model.dart';
import '../../models/recurring_expense_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/category_icon.dart';
import '../../utils/frequency.dart';
import '../../utils/period_calculator.dart';
import '../../utils/recurring_status.dart';
import '../../widgets/finance/finance_widgets.dart';
import 'add_recurring_page.dart';
import 'recurring_details_page.dart';

class RecurringListPage extends StatefulWidget {
  const RecurringListPage({super.key});

  @override
  State<RecurringListPage> createState() => _RecurringListPageState();
}

class _RecurringLine {
  final RecurringExpenseModel expense;
  final String status; // upcoming | overdue | paid

  _RecurringLine({required this.expense, required this.status});
}

class _RecurringListPageState extends State<RecurringListPage> {
  final FirestoreService _firestoreService = FirestoreService.instance;

  bool isLoading = true;
  List<_RecurringLine> lines = [];
  Map<String, CategoryModel> categoriesById = {};
  String search = '';
  String filter = 'All';

  static const List<String> _filters = ['All', 'Upcoming', 'Overdue', 'Paid'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => isLoading = true);
    try {
      final expenses = await _firestoreService.getRecurringExpenses();
      final categories = await _firestoreService.getCategoriesByType('expense');
      final today = PeriodCalculator.formatDate(DateTime.now());

      final newLines = <_RecurringLine>[];
      for (final expense in expenses) {
        bool paidToday = false;
        if (expense.id != null) {
          final payments = await _firestoreService.getRecurringPayments(expense.id!);
          paidToday = payments.any((p) => p.paymentDate == today);
        }
        newLines.add(_RecurringLine(
          expense: expense,
          status: computeRecurringStatus(nextDueDate: expense.nextDueDate, paidToday: paidToday),
        ));
      }

      if (!mounted) return;
      setState(() {
        lines = newLines;
        categoriesById = {for (final c in categories) if (c.id != null) c.id!: c};
        isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Error loading recurring expenses: $error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final overdue = lines.where((l) => l.status == 'overdue').length;
    final upcoming = lines.where((l) => l.status == 'upcoming').length;
    final monthly = lines.fold<double>(0, (s, l) => s + _monthlyFactor(l.expense.frequency) * l.expense.amount);

    final filtered = lines.where((l) {
      final matchesSearch = l.expense.name.toLowerCase().contains(search.toLowerCase());
      final matchesFilter = filter == 'All' || recurringStatusLabel(l.status) == filter;
      return matchesSearch && matchesFilter;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Recurring', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  if (lines.isNotEmpty) ...[
                    Row(
                      children: [
                        Expanded(child: _summaryTile('Monthly', 'Rs ${monthly.toStringAsFixed(0)}', AppColors.primary)),
                        const SizedBox(width: 8),
                        Expanded(child: _summaryTile('Upcoming', '$upcoming', AppColors.warning)),
                        const SizedBox(width: 8),
                        Expanded(child: _summaryTile('Overdue', '$overdue', AppColors.error)),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextField(
                    onChanged: (v) => setState(() => search = v),
                    decoration: InputDecoration(
                      hintText: 'Search expenses...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _filters.map((f) {
                        final selected = filter == f;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(f),
                            selected: selected,
                            onSelected: (_) => setState(() => filter = f),
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 12),
                            backgroundColor: Colors.white,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (filtered.isEmpty)
                    FinanceEmptyState(
                      icon: Icons.autorenew_rounded,
                      title: search.isNotEmpty ? 'No results found' : 'No recurring expenses',
                      description: search.isNotEmpty
                          ? 'Try a different search term.'
                          : 'Add subscriptions, rent, insurance, and other regular payments.',
                      actionLabel: search.isNotEmpty ? null : 'Add Expense',
                      onAction: search.isNotEmpty ? null : _openAdd,
                    )
                  else
                    ...filtered.map(_line),
                ],
              ),
            ),
      floatingActionButton: FinanceFab(label: 'Add Expense', onPressed: _openAdd),
    );
  }

  double _monthlyFactor(String frequency) {
    switch (frequency) {
      case 'yearly':
        return 1 / 12;
      case 'quarterly':
        return 1 / 3;
      case 'weekly':
        return 4.33;
      case 'biweekly':
        return 2.17;
      case 'daily':
        return 30;
      case 'monthly':
      default:
        return 1;
    }
  }

  Widget _summaryTile(String label, String value, Color color) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _line(_RecurringLine line) {
    final expense = line.expense;
    final category = categoriesById[expense.categoryId];

    return Opacity(
      opacity: expense.isActive ? 1 : 0.55,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: AppCard(
          onTap: () => _openDetails(expense),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                child: Icon(
                  category != null ? getCategoryIcon(category.iconName) : Icons.autorenew,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(expense.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                        Text('Rs ${expense.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        expense.isActive
                            ? StatusBadge(label: recurringStatusLabel(line.status), color: recurringStatusColor(line.status))
                            : const StatusBadge(label: 'Inactive', color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(frequencyLabel(expense.frequency), style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                        const Spacer(),
                        Text(expense.nextDueDate, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openAdd() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddRecurringPage()),
    );
    if (saved == true) _load();
  }

  Future<void> _openDetails(RecurringExpenseModel expense) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RecurringDetailsPage(expenseId: expense.id!)),
    );
    _load();
  }
}
