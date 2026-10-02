import '../models/budget_model.dart';
import '../models/category_model.dart';

// Self-import so [BudgetInsight.evaluate] can reach the top-level
// percentageAboveBudget function: inside the class, that bare name resolves
// to the instance field of the same name instead.
import 'budget_insight_engine.dart' as engine;

/// Rule-based "Above Budget" insight: decides *whether* a category's actual
/// spending has exceeded its own budget, and — separately — how to phrase
/// that as a short recommendation. The two are kept apart (percentage/
/// isAboveBudget vs buildRecommendationText) so a real model call can later
/// replace only the wording step without touching the rule that decides
/// whether an insight fires at all.
///
/// There is no third-party LLM wired up here; buildRecommendationText is a
/// local template. The category/budget/actual/percentage values it's given
/// always come from the caller — it never computes or invents them itself.

// RULE: ABOVE BUDGET — START

/// `((actual - budget) / budget) * 100`. Only meaningful when `budget > 0`;
/// callers should check [isAboveBudget] first.
double percentageAboveBudget(double budget, double actual) {
  return ((actual - budget) / budget) * 100;
}

/// True only when there's a real budget to compare against and spending has
/// gone strictly past it. A zero/unset budget never triggers an insight —
/// there's nothing meaningful to be "above".
bool isAboveBudget(double budget, double actual) {
  return budget > 0 && actual > budget;
}

/// Fills the fixed recommendation template with the already-calculated
/// values. Does not calculate the percentage or look up the budget itself.
String buildRecommendationText({
  required String categoryName,
  required double budget,
  required double actual,
  required double pctOver,
}) {
  return 'You are spending approximately '
      '${pctOver.toStringAsFixed(0)}% above your $categoryName budget. '
      'Try to keep your $categoryName expenditure within '
      'Rs. ${budget.toStringAsFixed(0)} next month.';
}

/// One category's above-budget insight, ready for the Insights page to
/// render.
class BudgetInsight {
  final CategoryModel? category;
  final BudgetAllocation allocation;
  final BudgetModel budget;
  final double actualSpending;
  final double percentageAboveBudget;
  final String message;

  const BudgetInsight({
    required this.category,
    required this.allocation,
    required this.budget,
    required this.actualSpending,
    required this.percentageAboveBudget,
    required this.message,
  });

  /// Builds a [BudgetInsight] for [allocation]/[actualSpending], or returns
  /// null when this category isn't above its budget (per [isAboveBudget]).
  static BudgetInsight? evaluate({
    required BudgetModel budget,
    required BudgetAllocation allocation,
    required CategoryModel? category,
    required double actualSpending,
  }) {
    final budgetAmount = allocation.allocatedAmount;
    if (!isAboveBudget(budgetAmount, actualSpending)) return null;

    final pctOver = engine.percentageAboveBudget(budgetAmount, actualSpending);
    final categoryName = category?.name ?? 'this category';

    return BudgetInsight(
      category: category,
      allocation: allocation,
      budget: budget,
      actualSpending: actualSpending,
      percentageAboveBudget: pctOver,
      message: buildRecommendationText(
        categoryName: categoryName,
        budget: budgetAmount,
        actual: actualSpending,
        pctOver: pctOver,
      ),
    );
  }
}

// RULE: ABOVE BUDGET — END
