import 'package:flutter/material.dart';

import '../../models/budget_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/period_calculator.dart';
import '../../widgets/finance/dark_finance_widgets.dart';
import '../../widgets/finance/finance_widgets.dart' show StatusBadge;
import 'budget_detail_page.dart';
import 'create_budget_page.dart';

class BudgetsListPage extends StatefulWidget {
  const BudgetsListPage({super.key});

  @override
  State<BudgetsListPage> createState() => _BudgetsListPageState();
}

class _BudgetSummary {
  final BudgetModel budget;
  final double spent;

  _BudgetSummary({required this.budget, required this.spent});
}

class _BudgetsListPageState extends State<BudgetsListPage> {
  final FirestoreService _firestoreService = FirestoreService.instance;

  bool isLoading = true;
  List<_BudgetSummary> summaries = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);

    try {
      final budgets = await _firestoreService.getBudgets();
      final now = DateTime.now();
      final loaded = <_BudgetSummary>[];

      for (final budget in budgets) {
        final window = PeriodCalculator.windowFor(budget.period, now);
        double spent = 0;

        for (final allocation in budget.categoryAllocations) {
          spent += await _firestoreService.getSpentForCategoryInRange(
            allocation.categoryId,
            PeriodCalculator.formatDate(window.start),
            PeriodCalculator.formatDate(window.end),
          );
        }

        loaded.add(_BudgetSummary(budget: budget, spent: spent));
      }

      if (!mounted) return;
      setState(() {
        summaries = loaded;
        isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Error loading budgets: $error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = summaries.where((s) => s.budget.isActive).toList();

    return Scaffold(
      backgroundColor: FinanceDark.bg,
      appBar: AppBar(
        title: const Text(
          'Budgets',
          style: TextStyle(fontWeight: FontWeight.w800, color: FinanceDark.textPrimary),
        ),
        backgroundColor: FinanceDark.bg,
        foregroundColor: FinanceDark.textPrimary,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: FinanceDark.accent))
          : summaries.isEmpty
              ? DarkEmptyState(
                  icon: Icons.pie_chart_outline_rounded,
                  title: 'No budgets yet',
                  description:
                      'Create a reusable budget to start tracking your spending by category.',
                  actionLabel: 'Create Budget',
                  onAction: _openCreate,
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: FinanceDark.accent,
                  backgroundColor: FinanceDark.card,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    children: [
                      ...active.map(_budgetCard),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'budgetsFab',
        onPressed: _openCreate,
        backgroundColor: FinanceDark.accent,
        foregroundColor: FinanceDark.bg,
        icon: const Icon(Icons.add),
        label: const Text('New Budget', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _budgetCard(_BudgetSummary summary) {
    final budget = summary.budget;
    final remaining = budget.budgetAmount - summary.spent;
    final isOver = remaining < 0;

    return Opacity(
      opacity: budget.isActive ? 1 : 0.6,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DarkCard(
          onTap: () => _openDetail(budget),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      budget.budgetName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: FinanceDark.textPrimary,
                      ),
                    ),
                  ),
                  if (!budget.isActive)
                    const StatusBadge(label: 'Inactive', color: FinanceDark.textSecondary),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Monthly budget',
                style: const TextStyle(color: FinanceDark.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 14),
              DarkProgressBar(value: summary.spent, max: budget.budgetAmount),
              const SizedBox(height: 12),
              Row(
                children: [
                  _stat('Budget', _fmt(budget.budgetAmount), FinanceDark.textPrimary),
                  _stat('Spent', _fmt(summary.spent), isOver ? FinanceDark.error : FinanceDark.textPrimary),
                  _stat(
                    'Remaining',
                    _fmt(remaining.abs()),
                    isOver ? FinanceDark.error : FinanceDark.success,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: FinanceDark.textSecondary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  String _fmt(double amount) => 'Rs ${amount.toStringAsFixed(0)}';

  Future<void> _openCreate() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateBudgetPage()),
    );
    if (created == true) _loadData();
  }

  Future<void> _openDetail(BudgetModel budget) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BudgetDetailPage(budgetId: budget.id!)),
    );
    _loadData();
  }
}
