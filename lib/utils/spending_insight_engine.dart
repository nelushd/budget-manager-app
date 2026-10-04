import '../models/category_model.dart';
import '../models/recurring_expense_model.dart';
import '../models/transaction_model.dart';

const int minDaysForProjection = 5;


const double projectionMarginPercent = 5;


const double concentrationShareOfBudget = 0.60;

const int concentrationMinTransactions = 2;

// ---------------------------------------------------------------------------
// Rule 1 — projected to go over budget
// ---------------------------------------------------------------------------

// RULE: PROJECTED TO GO OVER — START

double projectedSpend(double spent, int daysElapsed, int daysInPeriod) {
  if (daysElapsed <= 0 || daysInPeriod <= 0 || daysElapsed >= daysInPeriod) {
    return spent;
  }
  return spent / daysElapsed * daysInPeriod;
}

double projectedOverBudgetPercent(double budget, double projected) {
  return ((projected - budget) / budget) * 100;
}

bool isProjectedOverBudget({
  required double budget,
  required double spent,
  required int daysElapsed,
  required int daysInPeriod,
}) {
  if (budget <= 0) return false;
  if (spent > budget) return false;
  if (daysElapsed < minDaysForProjection) return false;
  if (daysElapsed >= daysInPeriod) return false;

  final projected = projectedSpend(spent, daysElapsed, daysInPeriod);
  return projected > budget * (1 + projectionMarginPercent / 100);
}

String buildProjectionText({
  required String categoryName,
  required double budget,
  required double projected,
  required double pctOver,
}) {
  return 'At your current rate you will finish the month at about Rs. '
      '${projected.toStringAsFixed(0)} on $categoryName — roughly '
      '${pctOver.toStringAsFixed(0)}% above your Rs. '
      '${budget.toStringAsFixed(0)} budget.';
}

// RULE: PROJECTED TO GO OVER — END

// ---------------------------------------------------------------------------
// Rule 2 — upcoming recurring charges exceed what is left
// ---------------------------------------------------------------------------

// RULE: SCHEDULED CHARGES (RECURRING SHORTFALL) — START

double remainingBudget(double budget, double spent) {
  final remaining = budget - spent;
  return remaining > 0 ? remaining : 0;
}

double upcomingRecurringForCategory({
  required List<RecurringExpenseModel> recurringExpenses,
  required String categoryId,
  required String todayDate,
  required String periodEndDate,
}) {
  double total = 0;
  for (final expense in recurringExpenses) {
    if (!expense.isActive) continue;
    if (expense.categoryId != categoryId) continue;

    final due = expense.nextDueDate;
    if (due.isEmpty) continue;
    if (due.compareTo(todayDate) < 0) continue;
    if (due.compareTo(periodEndDate) > 0) continue;

    total += expense.amount;
  }
  return total;
}

bool isRecurringShortfall({
  required double budget,
  required double spent,
  required double upcomingRecurring,
}) {
  if (budget <= 0) return false;
  if (upcomingRecurring <= 0) return false;
  return upcomingRecurring > remainingBudget(budget, spent);
}

String buildRecurringShortfallText({
  required String categoryName,
  required double upcomingRecurring,
  required double remaining,
}) {
  return 'Rs. ${upcomingRecurring.toStringAsFixed(0)} of recurring '
      '$categoryName charges are due before month end, but only Rs. '
      '${remaining.toStringAsFixed(0)} of your budget remains.';
}

// RULE: SCHEDULED CHARGES (RECURRING SHORTFALL) — END

// ---------------------------------------------------------------------------
// Rule 3 — one purchase took a large share of the budget
// ---------------------------------------------------------------------------

// RULE: LARGE PURCHASES (CONCENTRATED PURCHASE) — START

double shareOfBudget(double amount, double budget) {
  if (budget <= 0) return 0;
  return amount / budget;
}

double largestTransactionAmount(List<TransactionModel> transactions) {
  double largest = 0;
  for (final transaction in transactions) {
    if (transaction.amount > largest) largest = transaction.amount;
  }
  return largest;
}

bool isConcentratedPurchase({
  required double largestAmount,
  required double budget,
  required int transactionCount,
}) {
  if (budget <= 0) return false;
  if (largestAmount <= 0) return false;
  if (transactionCount < concentrationMinTransactions) return false;
  return shareOfBudget(largestAmount, budget) >= concentrationShareOfBudget;
}

String buildConcentrationText({
  required String categoryName,
  required double largestAmount,
  required double budget,
  required double remaining,
}) {
  final pct = shareOfBudget(largestAmount, budget) * 100;
  return 'A single Rs. ${largestAmount.toStringAsFixed(0)} purchase used '
      '${pct.toStringAsFixed(0)}% of your $categoryName budget. Rs. '
      '${remaining.toStringAsFixed(0)} is left for the rest of the month.';
}

// RULE: LARGE PURCHASES (CONCENTRATED PURCHASE) — END

// ---------------------------------------------------------------------------
// The insight the page renders
// ---------------------------------------------------------------------------

enum SpendingInsightKind { projectedOver, recurringShortfall, largePurchase }


class SpendingInsight {
  final SpendingInsightKind kind;
  final CategoryModel? category;
  final String categoryId;
  final String message;
  final double magnitude;

  const SpendingInsight({
    required this.kind,
    required this.category,
    required this.categoryId,
    required this.message,
    required this.magnitude,
  });
}
