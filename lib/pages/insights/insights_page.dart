import 'package:flutter/material.dart';

import '../../models/budget_model.dart';
import '../../models/category_model.dart';
import '../../models/recurring_expense_model.dart';
import '../../models/transaction_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/budget_insight_engine.dart';
import '../../utils/category_color.dart';
import '../../utils/category_icon.dart';
import '../../utils/period_calculator.dart';
import '../../utils/spending_insight_engine.dart';
import '../../widgets/finance/dark_finance_widgets.dart';
import '../../widgets/finance/finance_widgets.dart' show StatusBadge;


///   * "Above Budget"        — spending has already passed the budget.
///   * "Projected to go over" — still inside the budget but on pace to pass it.
///   * "Scheduled charges"   — committed recurring charges exceed what's left.
///   * "Large purchases"     — one transaction ate a big share of the budget.

class InsightsPage extends StatefulWidget {
  const InsightsPage({super.key});

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  final FirestoreService _firestoreService = FirestoreService.instance;

  bool isLoading = true;
  List<BudgetInsight> insights = [];
  List<SpendingInsight> spendingInsights = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => isLoading = true);

    try {
      final results = await Future.wait([
        _firestoreService.getBudgets(),
        _firestoreService.getCategoriesByType('expense'),
        _firestoreService.getRecurringExpenses(),
      ]);
      if (!mounted) return;

      final budgets = results[0] as List<BudgetModel>;
      final categories = results[1] as List<CategoryModel>;
      final recurringExpenses = results[2] as List<RecurringExpenseModel>;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final todayDate = PeriodCalculator.formatDate(today);

      final found = <BudgetInsight>[];
      final spending = <SpendingInsight>[];

      for (final budget in budgets) {
        if (!budget.isActive) continue;

        final window = PeriodCalculator.windowFor(budget.period, now);
        final startDate = PeriodCalculator.formatDate(window.start);
        final endDate = PeriodCalculator.formatDate(window.end);

        final daysInPeriod = window.end.difference(window.start).inDays + 1;
        final daysElapsed =
            (today.difference(window.start).inDays + 1).clamp(0, daysInPeriod);

        for (final allocation in budget.categoryAllocations) {
          if (allocation.allocatedAmount <= 0) continue;

          final transactions =
              await _firestoreService.getTransactionsForCategoryInRange(
            allocation.categoryId,
            startDate,
            endDate,
          );
          final spent = transactions.fold<double>(
            0,
            (total, transaction) => total + transaction.amount,
          );

          CategoryModel? category;
          for (final c in categories) {
            if (c.id == allocation.categoryId) {
              category = c;
              break;
            }
          }
          final categoryName = category?.name ?? 'this category';
          final budgetAmount = allocation.allocatedAmount;

          // RULE: ABOVE BUDGET — START
          final insight = BudgetInsight.evaluate(
            budget: budget,
            allocation: allocation,
            category: category,
            actualSpending: spent,
          );
          if (insight != null) found.add(insight);
          // RULE: ABOVE BUDGET — END

          spending.addAll(_evaluateSpendingRules(
            category: category,
            categoryId: allocation.categoryId,
            categoryName: categoryName,
            budgetAmount: budgetAmount,
            spent: spent,
            transactions: transactions,
            recurringExpenses: recurringExpenses,
            todayDate: todayDate,
            periodEndDate: endDate,
            daysElapsed: daysElapsed,
            daysInPeriod: daysInPeriod,
          ));
        }
      }

      found.sort(
        (a, b) => b.percentageAboveBudget.compareTo(a.percentageAboveBudget),
      );
      spending.sort((a, b) => b.magnitude.compareTo(a.magnitude));

      if (!mounted) return;
      setState(() {
        insights = found;
        spendingInsights = spending;
        isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Error loading insights: $error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  
  List<SpendingInsight> _evaluateSpendingRules({
    required CategoryModel? category,
    required String categoryId,
    required String categoryName,
    required double budgetAmount,
    required double spent,
    required List<TransactionModel> transactions,
    required List<RecurringExpenseModel> recurringExpenses,
    required String todayDate,
    required String periodEndDate,
    required int daysElapsed,
    required int daysInPeriod,
  }) {
    final results = <SpendingInsight>[];
    final remaining = remainingBudget(budgetAmount, spent);

    // RULE: PROJECTED TO GO OVER — START
    if (isProjectedOverBudget(
      budget: budgetAmount,
      spent: spent,
      daysElapsed: daysElapsed,
      daysInPeriod: daysInPeriod,
    )) {
      final projected = projectedSpend(spent, daysElapsed, daysInPeriod);
      final pctOver = projectedOverBudgetPercent(budgetAmount, projected);
      results.add(SpendingInsight(
        kind: SpendingInsightKind.projectedOver,
        category: category,
        categoryId: categoryId,
        magnitude: pctOver,
        message: buildProjectionText(
          categoryName: categoryName,
          budget: budgetAmount,
          projected: projected,
          pctOver: pctOver,
        ),
      ));
    }
    // RULE: PROJECTED TO GO OVER — END

    // RULE: SCHEDULED CHARGES (RECURRING SHORTFALL) — START
    final upcoming = upcomingRecurringForCategory(
      recurringExpenses: recurringExpenses,
      categoryId: categoryId,
      todayDate: todayDate,
      periodEndDate: periodEndDate,
    );
    if (isRecurringShortfall(
      budget: budgetAmount,
      spent: spent,
      upcomingRecurring: upcoming,
    )) {
      results.add(SpendingInsight(
        kind: SpendingInsightKind.recurringShortfall,
        category: category,
        categoryId: categoryId,
        magnitude: upcoming - remaining,
        message: buildRecurringShortfallText(
          categoryName: categoryName,
          upcomingRecurring: upcoming,
          remaining: remaining,
        ),
      ));
    }
    // RULE: SCHEDULED CHARGES (RECURRING SHORTFALL) — END

    // RULE: LARGE PURCHASES (CONCENTRATED PURCHASE) — START
    final largest = largestTransactionAmount(transactions);
    if (isConcentratedPurchase(
      largestAmount: largest,
      budget: budgetAmount,
      transactionCount: transactions.length,
    )) {
      results.add(SpendingInsight(
        kind: SpendingInsightKind.largePurchase,
        category: category,
        categoryId: categoryId,
        magnitude: shareOfBudget(largest, budgetAmount) * 100,
        message: buildConcentrationText(
          categoryName: categoryName,
          largestAmount: largest,
          budget: budgetAmount,
          remaining: remaining,
        ),
      ));
    }
    // RULE: LARGE PURCHASES (CONCENTRATED PURCHASE) — END

    return results;
  }

  Future<void> _setBudget(BudgetInsight insight) async {
    final updatedAllocations = insight.budget.categoryAllocations.map((a) {
      if (a.categoryId != insight.allocation.categoryId) return a;
      return a.copyWith(allocatedAmount: insight.allocation.allocatedAmount);
    }).toList();

    await _firestoreService.updateBudget(
      insight.budget.copyWith(categoryAllocations: updatedAllocations),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Budget confirmed at Rs. '
            '${insight.allocation.allocatedAmount.toStringAsFixed(0)}.',
          ),
          backgroundColor: Colors.black87,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  List<SpendingInsight> _ofKind(SpendingInsightKind kind) {
    return spendingInsights.where((i) => i.kind == kind).toList();
  }

  @override
  Widget build(BuildContext context) {
    final projected = _ofKind(SpendingInsightKind.projectedOver);
    final scheduled = _ofKind(SpendingInsightKind.recurringShortfall);
    final large = _ofKind(SpendingInsightKind.largePurchase);
    final hasAnything = insights.isNotEmpty ||
        projected.isNotEmpty ||
        scheduled.isNotEmpty ||
        large.isNotEmpty;

    return Scaffold(
      backgroundColor: FinanceDark.bg,
      appBar: AppBar(
        title: const Text(
          'Insights',
          style: TextStyle(fontWeight: FontWeight.w800, color: FinanceDark.textPrimary),
        ),
        backgroundColor: FinanceDark.bg,
        foregroundColor: FinanceDark.textPrimary,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: FinanceDark.accent),
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: FinanceDark.accent,
              backgroundColor: FinanceDark.card,
              child: !hasAnything
                  ? ListView(
                      children: const [
                        DarkEmptyState(
                          icon: Icons.check_circle_outline_rounded,
                          title: "You're within your budgets",
                          description: 'Keep up the good work!',
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      children: [
                        if (insights.isNotEmpty) ...[
                          const DarkSectionLabel('Above Budget'),
                          const SizedBox(height: 8),
                          ...insights.map(_insightCard),
                        ],
                        if (projected.isNotEmpty) ...[
                          const DarkSectionLabel('Projected To Go Over'),
                          const SizedBox(height: 8),
                          ...projected.map(_spendingCard),
                        ],
                        if (scheduled.isNotEmpty) ...[
                          const DarkSectionLabel('Scheduled Charges'),
                          const SizedBox(height: 8),
                          ...scheduled.map(_spendingCard),
                        ],
                        if (large.isNotEmpty) ...[
                          const DarkSectionLabel('Large Purchases'),
                          const SizedBox(height: 8),
                          ...large.map(_spendingCard),
                        ],
                      ],
                    ),
            ),
    );
  }

  Widget _insightCard(BudgetInsight insight) {
    final name = insight.category?.name ?? 'Unknown category';

    return _card(
      categoryId: insight.allocation.categoryId,
      category: insight.category,
      name: name,
      badgeLabel: '+${insight.percentageAboveBudget.toStringAsFixed(0)}%',
      badgeColor: FinanceDark.error,
      message: insight.message,
      action: DarkActionButton(
        label: 'Set Budget to Rs. '
            '${insight.allocation.allocatedAmount.toStringAsFixed(0)}',
        variant: DarkActionVariant.secondary,
        onPressed: () => _setBudget(insight),
      ),
    );
  }

  Widget _spendingCard(SpendingInsight insight) {
    final name = insight.category?.name ?? 'Unknown category';

    late final String badgeLabel;
    late final Color badgeColor;
    switch (insight.kind) {
      case SpendingInsightKind.projectedOver:
        badgeLabel = '~+${insight.magnitude.toStringAsFixed(0)}%';
        badgeColor = FinanceDark.warning;
      case SpendingInsightKind.recurringShortfall:
        badgeLabel = 'Due soon';
        badgeColor = FinanceDark.error;
      case SpendingInsightKind.largePurchase:
        badgeLabel = '${insight.magnitude.toStringAsFixed(0)}%';
        badgeColor = FinanceDark.info;
    }

    return _card(
      categoryId: insight.categoryId,
      category: insight.category,
      name: name,
      badgeLabel: badgeLabel,
      badgeColor: badgeColor,
      message: insight.message,
    );
  }

  Widget _card({
    required String categoryId,
    required CategoryModel? category,
    required String name,
    required String badgeLabel,
    required Color badgeColor,
    required String message,
    Widget? action,
  }) {
    final color = colorForCategory(categoryId);
    final icon =
        category != null ? getCategoryIcon(category.iconName) : Icons.category;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DarkCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: FinanceDark.textPrimary),
                  ),
                ),
                StatusBadge(label: badgeLabel, color: badgeColor),
              ],
            ),
            const SizedBox(height: 10),
            Text(message, style: const TextStyle(height: 1.4, color: FinanceDark.textSecondary)),
            if (action != null) ...[
              const SizedBox(height: 14),
              action,
            ],
          ],
        ),
      ),
    );
  }
}
