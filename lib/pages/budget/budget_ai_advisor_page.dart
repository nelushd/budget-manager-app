import 'package:flutter/material.dart';

import '../../models/budget_model.dart';
import '../../models/category_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/category_color.dart';
import '../../utils/category_icon.dart';
import '../../utils/period_calculator.dart';
import '../../widgets/finance/dark_finance_widgets.dart';

/// Rule-based recommendation, computed from the last 3 real periods of
/// actual spend (via FirestoreService.getSpentForCategoryInRange). This is
/// a local heuristic, not a live LLM call — there's no backend/API key
/// wired up for that.
class _Recommendation {
  final BudgetAllocation allocation;
  final CategoryModel? category;
  final double averageSpend;
  final double recommended;
  final String reason;

  _Recommendation({
    required this.allocation,
    required this.category,
    required this.averageSpend,
    required this.recommended,
    required this.reason,
  });

  double get diff => recommended - allocation.allocatedAmount;
}

class BudgetAiAdvisorPage extends StatefulWidget {
  final BudgetModel budget;

  const BudgetAiAdvisorPage({super.key, required this.budget});

  @override
  State<BudgetAiAdvisorPage> createState() => _BudgetAiAdvisorPageState();
}

class _BudgetAiAdvisorPageState extends State<BudgetAiAdvisorPage> {
  final FirestoreService _firestoreService = FirestoreService.instance;

  bool isLoading = true;
  bool applied = false;
  List<_Recommendation> recommendations = [];
  final Set<String> selected = {};

  @override
  void initState() {
    super.initState();
    _compute();
  }

  Future<void> _compute() async {
    final categories = await _firestoreService.getCategoriesByType('expense');
    final windows = PeriodCalculator.previousPeriods(
      widget.budget.period,
      DateTime.now(),
      3,
    );

    final results = <_Recommendation>[];

    for (final allocation in widget.budget.categoryAllocations) {
      double total = 0;
      for (final window in windows) {
        total += await _firestoreService.getSpentForCategoryInRange(
          allocation.categoryId,
          PeriodCalculator.formatDate(window.start),
          PeriodCalculator.formatDate(window.end),
        );
      }
      final average = windows.isEmpty ? 0.0 : total / windows.length;

      double recommended = allocation.allocatedAmount;
      String reason = 'Right on track — no change needed.';

      if (average > allocation.allocatedAmount) {
        recommended = (average * 1.05);
        reason = 'You typically go over this allocation — raising it covers the usual overage.';
      } else if (average > 0 && average < allocation.allocatedAmount * 0.7) {
        recommended = (average * 1.1);
        reason = 'You consistently spend well under this allocation — lowering it frees up budget elsewhere.';
      } else if (average == 0) {
        reason = 'No recent spending history in this category yet.';
      }

      CategoryModel? category;
      for (final c in categories) {
        if (c.id == allocation.categoryId) {
          category = c;
          break;
        }
      }

      final rec = _Recommendation(
        allocation: allocation,
        category: category,
        averageSpend: average,
        recommended: recommended.roundToDouble(),
        reason: reason,
      );
      results.add(rec);
      if (rec.diff != 0) selected.add(allocation.categoryId);
    }

    if (!mounted) return;
    setState(() {
      recommendations = results;
      isLoading = false;
    });
  }

  Future<void> _apply() async {
    final updatedAllocations = widget.budget.categoryAllocations.map((a) {
      if (!selected.contains(a.categoryId)) return a;
      final rec = recommendations.firstWhere((r) => r.allocation.categoryId == a.categoryId);
      return a.copyWith(allocatedAmount: rec.recommended);
    }).toList();

    await _firestoreService.updateBudget(
      widget.budget.copyWith(categoryAllocations: updatedAllocations),
    );

    if (!mounted) return;
    setState(() => applied = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (applied) {
      return const Scaffold(
        backgroundColor: FinanceDark.bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded, color: FinanceDark.success, size: 64),
              SizedBox(height: 16),
              Text(
                'Applied!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: FinanceDark.textPrimary),
              ),
              SizedBox(height: 6),
              Text('Your budget has been updated.', style: TextStyle(color: FinanceDark.textSecondary)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: FinanceDark.bg,
      appBar: AppBar(
        title: const Text('Budget Advisor', style: TextStyle(color: FinanceDark.textPrimary, fontWeight: FontWeight.w800)),
        backgroundColor: FinanceDark.bg,
        foregroundColor: FinanceDark.textPrimary,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: FinanceDark.accent))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF115E59), FinanceDark.accent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Based on your last 3 periods of real spending, here\'s where your allocations could shift.',
                    style: TextStyle(color: Colors.white, height: 1.4),
                  ),
                ),
                const SizedBox(height: 18),
                const DarkSectionLabel('Recommendations'),
                ...recommendations.map((rec) {
                  final isSelected = selected.contains(rec.allocation.categoryId);
                  final noChange = rec.diff == 0;
                  final color = colorForCategory(rec.allocation.categoryId);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DarkCard(
                      onTap: noChange
                          ? null
                          : () => setState(() {
                                if (isSelected) {
                                  selected.remove(rec.allocation.categoryId);
                                } else {
                                  selected.add(rec.allocation.categoryId);
                                }
                              }),
                      borderColor: isSelected ? FinanceDark.accent : null,
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
                                child: Icon(
                                  rec.category != null
                                      ? getCategoryIcon(rec.category!.iconName)
                                      : Icons.category,
                                  color: color,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  rec.category?.name ?? 'Unknown',
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: FinanceDark.textPrimary),
                                ),
                              ),
                              if (!noChange)
                                Icon(
                                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                                  color: isSelected ? FinanceDark.accent : FinanceDark.textSecondary,
                                )
                              else
                                const Text('No change', style: TextStyle(color: FinanceDark.textSecondary, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _amountBox('Current', rec.allocation.allocatedAmount, FinanceDark.bg),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _amountBox(
                                  'Recommended',
                                  rec.recommended,
                                  rec.diff < 0
                                      ? FinanceDark.success.withValues(alpha: 0.16)
                                      : rec.diff > 0
                                          ? FinanceDark.warning.withValues(alpha: 0.16)
                                          : FinanceDark.bg,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(rec.reason, style: const TextStyle(fontSize: 12, color: FinanceDark.textSecondary)),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                DarkActionButton(
                  label: 'Apply Selected (${selected.length})',
                  onPressed: selected.isEmpty ? null : _apply,
                ),
                const SizedBox(height: 10),
                DarkActionButton(
                  label: 'Keep Current Budget',
                  variant: DarkActionVariant.secondary,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
    );
  }

  Widget _amountBox(String label, double value, Color background) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FinanceDark.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: FinanceDark.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('Rs ${value.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, color: FinanceDark.textPrimary)),
        ],
      ),
    );
  }
}
