import '../models/budget_model.dart';
import '../models/category_model.dart';
import 'budget_insight_engine.dart' as engine;


// RULE: ABOVE BUDGET — START


double percentageAboveBudget(double budget, double actual) {
  return ((actual - budget) / budget) * 100;
}

bool isAboveBudget(double budget, double actual) {
  return budget > 0 && actual > budget;
}

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
