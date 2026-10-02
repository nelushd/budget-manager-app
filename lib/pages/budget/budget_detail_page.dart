import 'package:flutter/material.dart';

import '../../models/budget_model.dart';
import '../../models/category_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/category_color.dart';
import '../../utils/category_icon.dart';
import '../../utils/period_calculator.dart';
import '../../widgets/finance/circular_progress_ring.dart';
import '../../widgets/finance/dark_finance_widgets.dart';
import '../../widgets/finance/finance_widgets.dart' show StatusBadge;
import 'budget_ai_advisor_page.dart';
import 'create_budget_page.dart';

class BudgetDetailPage extends StatefulWidget {
  final String budgetId;

  const BudgetDetailPage({super.key, required this.budgetId});

  @override
  State<BudgetDetailPage> createState() => _BudgetDetailPageState();
}

class _CategoryLine {
  final CategoryModel? category;
  final BudgetAllocation allocation;
  final double spent;

  _CategoryLine({required this.category, required this.allocation, required this.spent});
}

class _BudgetDetailPageState extends State<BudgetDetailPage> {
  final FirestoreService _firestoreService = FirestoreService.instance;

  bool isLoading = true;
  BudgetModel? budget;
  DateTime referenceDate = DateTime.now();
  PeriodWindow? window;
  bool canGoPrev = false;
  bool canGoNext = false;
  List<_CategoryLine> lines = [];
  bool showDeleteConfirm = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => isLoading = true);

    try {
      final loaded = await _firestoreService.getBudgetById(widget.budgetId);
      if (loaded == null) {
        if (!mounted) return;
        setState(() {
          budget = null;
          isLoading = false;
        });
        return;
      }

      final categories = await _firestoreService.getCategoriesByType('expense');
      if (!mounted) return;

      setState(() => budget = loaded);
      await _computePeriod(categories);
    } catch (error, stackTrace) {
      debugPrint('Error loading budget detail: $error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  DateTime? get _startBound => budget != null && budget!.startDate.isNotEmpty
      ? PeriodCalculator.parseDate(budget!.startDate)
      : null;

  DateTime? get _endBound =>
      budget?.endDate != null ? PeriodCalculator.parseDate(budget!.endDate!) : null;

  Future<void> _computePeriod(List<CategoryModel> categories) async {
    final b = budget!;
    final rawWindow = PeriodCalculator.windowFor(b.period, referenceDate);
    final clipped = PeriodCalculator.clip(
      rawWindow,
      startBound: _startBound,
      endBound: _endBound,
    );

    final prevRef = PeriodCalculator.shift(b.period, referenceDate, -1);
    final prevClipped = PeriodCalculator.clip(
      PeriodCalculator.windowFor(b.period, prevRef),
      startBound: _startBound,
      endBound: _endBound,
    );

    final nextRef = PeriodCalculator.shift(b.period, referenceDate, 1);
    final nextClipped = PeriodCalculator.clip(
      PeriodCalculator.windowFor(b.period, nextRef),
      startBound: _startBound,
      endBound: _endBound,
    );

    final newLines = <_CategoryLine>[];
    if (clipped != null) {
      for (final allocation in b.categoryAllocations) {
        final spent = await _firestoreService.getSpentForCategoryInRange(
          allocation.categoryId,
          PeriodCalculator.formatDate(clipped.start),
          PeriodCalculator.formatDate(clipped.end),
        );
        CategoryModel? category;
        for (final c in categories) {
          if (c.id == allocation.categoryId) {
            category = c;
            break;
          }
        }
        newLines.add(_CategoryLine(category: category, allocation: allocation, spent: spent));
      }
    }

    if (!mounted) return;
    setState(() {
      window = clipped;
      lines = newLines;
      canGoPrev = prevClipped != null;
      canGoNext = nextClipped != null && !rawWindow.start.isAfter(DateTime.now());
      isLoading = false;
    });
  }

  Future<void> _navigate(int steps) async {
    if (budget == null) return;
    setState(() {
      isLoading = true;
      referenceDate = PeriodCalculator.shift(budget!.period, referenceDate, steps);
    });
    final categories = await _firestoreService.getCategoriesByType('expense');
    await _computePeriod(categories);
  }

  Future<void> _toggleActive() async {
    final b = budget;
    if (b == null) return;
    final updated = b.copyWith(status: b.isActive ? 'inactive' : 'active');
    await _firestoreService.updateBudget(updated);
    setState(() => budget = updated);
  }

  Future<void> _delete() async {
    final b = budget;
    if (b?.id == null) return;
    await _firestoreService.deleteBudget(b!.id!);
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _edit() async {
    final b = budget;
    if (b == null) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CreateBudgetPage(existing: b)),
    );
    if (saved == true) _load();
  }

  String _periodTitle() {
    final b = budget;
    final w = window;
    if (b == null || w == null) return '';

    switch (b.period) {
      case 'daily':
        return _fmtDay(w.start);
      case 'weekly':
        return '${_fmtDay(w.start)} - ${_fmtDay(w.end)}';
      case 'quarterly':
        final q = ((w.start.month - 1) ~/ 3) + 1;
        return 'Q$q ${w.start.year}';
      case 'yearly':
        return '${w.start.year}';
      case 'monthly':
      default:
        return _fmtMonth(w.start);
    }
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _fmtDay(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';
  String _fmtMonth(DateTime d) => '${_months[d.month - 1]} ${d.year}';

  @override
  Widget build(BuildContext context) {
    final b = budget;

    if (isLoading && b == null) {
      return const Scaffold(
        backgroundColor: FinanceDark.bg,
        body: Center(child: CircularProgressIndicator(color: FinanceDark.accent)),
      );
    }

    if (b == null) {
      return const Scaffold(
        backgroundColor: FinanceDark.bg,
        body: Center(
          child: Text('Budget not found', style: TextStyle(color: FinanceDark.textPrimary)),
        ),
      );
    }

    final totalSpent = lines.fold<double>(0, (s, l) => s + l.spent);
    final remaining = b.budgetAmount - totalSpent;
    final pct = b.budgetAmount > 0 ? (totalSpent / b.budgetAmount * 100) : 0.0;
    final isOver = remaining < 0;

    return Scaffold(
      backgroundColor: FinanceDark.bg,
      appBar: AppBar(
        title: Text(
          b.budgetName,
          style: const TextStyle(fontWeight: FontWeight.w800, color: FinanceDark.textPrimary),
        ),
        backgroundColor: FinanceDark.bg,
        foregroundColor: FinanceDark.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'AI Tips',
            icon: const Icon(Icons.auto_graph_rounded, color: FinanceDark.accent),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => BudgetAiAdvisorPage(budget: b)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: FinanceDark.textPrimary),
            onPressed: _edit,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: FinanceDark.accent))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: canGoPrev ? () => _navigate(-1) : null,
                      icon: const Icon(Icons.chevron_left),
                      color: FinanceDark.textPrimary,
                      disabledColor: FinanceDark.divider,
                    ),
                    SizedBox(
                      width: 160,
                      child: Text(
                        _periodTitle(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700, color: FinanceDark.textPrimary),
                      ),
                    ),
                    IconButton(
                      onPressed: canGoNext ? () => _navigate(1) : null,
                      icon: const Icon(Icons.chevron_right),
                      color: FinanceDark.textPrimary,
                      disabledColor: FinanceDark.divider,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DarkCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircularProgressRing(
                            percentage: pct.clamp(0, 100),
                            size: 84,
                            strokeWidth: 8,
                            color: isOver ? FinanceDark.error : FinanceDark.accent,
                            trackColor: FinanceDark.divider,
                            child: Text(
                              '${pct.toStringAsFixed(0)}%',
                              style: const TextStyle(fontWeight: FontWeight.w800, color: FinanceDark.textPrimary),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                StatusBadge(
                                  label: b.isActive ? 'Active' : 'Inactive',
                                  color: b.isActive ? FinanceDark.success : FinanceDark.textSecondary,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Rs ${b.budgetAmount.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: FinanceDark.textPrimary,
                                  ),
                                ),
                                const Text('Total budget', style: TextStyle(color: FinanceDark.textSecondary, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DarkProgressBar(value: totalSpent, max: b.budgetAmount),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _stat('Spent', 'Rs ${totalSpent.toStringAsFixed(0)}', isOver ? FinanceDark.error : FinanceDark.textPrimary),
                          _stat('Remaining', 'Rs ${remaining.abs().toStringAsFixed(0)}', isOver ? FinanceDark.error : FinanceDark.success),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const DarkSectionLabel('Category Breakdown'),
                if (window == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'This period is outside the budget\'s active range.',
                      style: TextStyle(color: FinanceDark.textSecondary),
                    ),
                  )
                else
                  ...lines.map((line) {
                    final color = colorForCategory(line.allocation.categoryId);
                    final name = line.category?.name ?? 'Unknown category';
                    final icon = line.category != null
                        ? getCategoryIcon(line.category!.iconName)
                        : Icons.category;
                    final catRemaining = line.allocation.allocatedAmount - line.spent;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DarkCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
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
                              ],
                            ),
                            const SizedBox(height: 10),
                            DarkProgressBar(
                              value: line.spent,
                              max: line.allocation.allocatedAmount,
                              color: color,
                              thin: true,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _stat('Allocated', 'Rs ${line.allocation.allocatedAmount.toStringAsFixed(0)}', FinanceDark.textPrimary),
                                _stat('Spent', 'Rs ${line.spent.toStringAsFixed(0)}', line.spent > line.allocation.allocatedAmount ? FinanceDark.error : FinanceDark.textPrimary),
                                _stat('Remaining', 'Rs ${catRemaining.abs().toStringAsFixed(0)}', catRemaining < 0 ? FinanceDark.error : FinanceDark.success),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 12),
                DarkActionButton(
                  label: b.isActive ? 'Deactivate Budget' : 'Activate Budget',
                  variant: DarkActionVariant.secondary,
                  onPressed: _toggleActive,
                ),
                const SizedBox(height: 10),
                if (showDeleteConfirm)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: FinanceDark.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: FinanceDark.error.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Delete this budget?',
                          style: TextStyle(fontWeight: FontWeight.w700, color: FinanceDark.textPrimary),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => setState(() => showDeleteConfirm = false),
                                child: const Text('Cancel', style: TextStyle(color: FinanceDark.textSecondary)),
                              ),
                            ),
                            Expanded(
                              child: TextButton(
                                onPressed: _delete,
                                child: const Text('Delete', style: TextStyle(color: FinanceDark.error)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                else
                  DarkActionButton(
                    label: 'Delete Budget',
                    variant: DarkActionVariant.danger,
                    onPressed: () => setState(() => showDeleteConfirm = true),
                  ),
              ],
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
}
