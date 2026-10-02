import 'package:flutter_test/flutter_test.dart';

import 'package:budget_manager_app/models/recurring_expense_model.dart';
import 'package:budget_manager_app/models/transaction_model.dart';
import 'package:budget_manager_app/utils/spending_insight_engine.dart';

RecurringExpenseModel _recurring({
  required String categoryId,
  required double amount,
  required String nextDueDate,
  String status = 'active',
}) {
  return RecurringExpenseModel(
    userId: 'u1',
    name: 'charge',
    amount: amount,
    categoryId: categoryId,
    frequency: 'monthly',
    startDate: '2026-01-01',
    nextDueDate: nextDueDate,
    accountId: 'a1',
    status: status,
    createdDate: 0,
  );
}

TransactionModel _txn(double amount) {
  return TransactionModel(
    userId: 'u1',
    amount: amount,
    type: 'expense',
    categoryId: 'c1',
    accountId: 'a1',
    date: '2026-08-10',
    time: '10:00',
    createdAt: 0,
  );
}

void main() {
  group('projectedSpend', () {
    test('extrapolates a part-month rate to the full period', () {
      // Rs. 4,000 over 10 days of a 30-day month -> Rs. 12,000.
      expect(projectedSpend(4000, 10, 30), closeTo(12000, 0.001));
    });

    test('returns spend unchanged once the period is over', () {
      expect(projectedSpend(4000, 30, 30), 4000);
      expect(projectedSpend(4000, 31, 30), 4000);
    });

    test('never projects below what is already spent', () {
      expect(projectedSpend(4000, 0, 30), 4000);
      expect(projectedSpend(4000, 10, 0), 4000);
    });
  });

  group('isProjectedOverBudget', () {
    test('fires when on pace to pass the budget', () {
      // 4,000 in 10 days -> 12,000 projected against an 8,000 budget.
      expect(
        isProjectedOverBudget(
          budget: 8000,
          spent: 4000,
          daysElapsed: 10,
          daysInPeriod: 30,
        ),
        isTrue,
      );
    });

    test('stays quiet when the projection lands inside the budget', () {
      // 2,000 in 10 days -> 6,000 projected against an 8,000 budget.
      expect(
        isProjectedOverBudget(
          budget: 8000,
          spent: 2000,
          daysElapsed: 10,
          daysInPeriod: 30,
        ),
        isFalse,
      );
    });

    test('stays quiet inside the margin', () {
      // 2,700 in 10 days -> 8,100 projected, only 1.25% over an 8,000
      // budget, which is inside projectionMarginPercent.
      expect(
        isProjectedOverBudget(
          budget: 8000,
          spent: 2700,
          daysElapsed: 10,
          daysInPeriod: 30,
        ),
        isFalse,
      );
    });

    test('stays quiet too early in the period', () {
      // Same runaway rate, but only 2 days in.
      expect(
        isProjectedOverBudget(
          budget: 8000,
          spent: 4000,
          daysElapsed: 2,
          daysInPeriod: 30,
        ),
        isFalse,
      );
    });

    test('defers to the Above Budget rule once already over', () {
      expect(
        isProjectedOverBudget(
          budget: 8000,
          spent: 9000,
          daysElapsed: 10,
          daysInPeriod: 30,
        ),
        isFalse,
      );
    });

    test('stays quiet on the last day, when there is nothing left to project',
        () {
      expect(
        isProjectedOverBudget(
          budget: 8000,
          spent: 7000,
          daysElapsed: 30,
          daysInPeriod: 30,
        ),
        isFalse,
      );
    });

    test('a zero/unset budget never projects', () {
      expect(
        isProjectedOverBudget(
          budget: 0,
          spent: 4000,
          daysElapsed: 10,
          daysInPeriod: 30,
        ),
        isFalse,
      );
    });
  });

  group('remainingBudget', () {
    test('returns what is left', () {
      expect(remainingBudget(8000, 5740), closeTo(2260, 0.001));
    });

    test('clamps to zero rather than going negative', () {
      expect(remainingBudget(3000, 3900), 0);
    });
  });

  group('upcomingRecurringForCategory', () {
    final expenses = [
      _recurring(categoryId: 'c1', amount: 1500, nextDueDate: '2026-08-20'),
      _recurring(categoryId: 'c1', amount: 900, nextDueDate: '2026-08-28'),
      _recurring(categoryId: 'c2', amount: 5000, nextDueDate: '2026-08-25'),
      _recurring(categoryId: 'c1', amount: 700, nextDueDate: '2026-09-03'),
      _recurring(categoryId: 'c1', amount: 400, nextDueDate: '2026-08-05'),
      _recurring(
        categoryId: 'c1',
        amount: 8000,
        nextDueDate: '2026-08-22',
        status: 'inactive',
      ),
    ];

    test('sums only this category, still due, inside the period', () {
      final total = upcomingRecurringForCategory(
        recurringExpenses: expenses,
        categoryId: 'c1',
        todayDate: '2026-08-15',
        periodEndDate: '2026-08-31',
      );

      // 1500 + 900 only: c2 is another category, Sep 3 is past the period,
      // Aug 5 already passed, and the 8,000 charge is inactive.
      expect(total, closeTo(2400, 0.001));
    });

    test('a charge due today still counts', () {
      final total = upcomingRecurringForCategory(
        recurringExpenses: expenses,
        categoryId: 'c1',
        todayDate: '2026-08-20',
        periodEndDate: '2026-08-31',
      );
      expect(total, closeTo(2400, 0.001));
    });
  });

  group('isRecurringShortfall', () {
    test('fires when committed charges exceed what is left', () {
      // 800 left, 2,400 already scheduled.
      expect(
        isRecurringShortfall(
          budget: 5000,
          spent: 4200,
          upcomingRecurring: 2400,
        ),
        isTrue,
      );
    });

    test('stays quiet when the remaining budget covers them', () {
      expect(
        isRecurringShortfall(
          budget: 5000,
          spent: 1000,
          upcomingRecurring: 2400,
        ),
        isFalse,
      );
    });

    test('exactly covered is not a shortfall', () {
      expect(
        isRecurringShortfall(
          budget: 5000,
          spent: 2600,
          upcomingRecurring: 2400,
        ),
        isFalse,
      );
    });

    test('nothing scheduled never fires', () {
      expect(
        isRecurringShortfall(
          budget: 5000,
          spent: 4900,
          upcomingRecurring: 0,
        ),
        isFalse,
      );
    });
  });

  group('largestTransactionAmount', () {
    test('picks the biggest expense', () {
      expect(largestTransactionAmount([_txn(300), _txn(2800), _txn(950)]),
          closeTo(2800, 0.001));
    });

    test('an empty month has no largest purchase', () {
      expect(largestTransactionAmount([]), 0);
    });
  });

  group('isConcentratedPurchase', () {
    test('fires when one purchase takes a large share of the budget', () {
      // 2,900 of a 3,000 budget -> 97%, alongside other spending.
      expect(
        isConcentratedPurchase(
          largestAmount: 2900,
          budget: 3000,
          transactionCount: 4,
        ),
        isTrue,
      );
    });

    test('stays quiet for an ordinary purchase', () {
      expect(
        isConcentratedPurchase(
          largestAmount: 500,
          budget: 3000,
          transactionCount: 4,
        ),
        isFalse,
      );
    });

    test('stays quiet below the threshold', () {
      // 45% of the budget — real, but not worth a card of its own.
      expect(
        isConcentratedPurchase(
          largestAmount: 4500,
          budget: 10000,
          transactionCount: 4,
        ),
        isFalse,
      );
    });

    test('exactly at the threshold fires', () {
      expect(
        isConcentratedPurchase(
          largestAmount: 1800,
          budget: 3000,
          transactionCount: 4,
        ),
        isTrue,
      );
    });

    test('a lone transaction is a tautology, not an insight', () {
      // Rent: one Rs. 35,000 payment against a Rs. 35,000 budget. "One
      // purchase used 100% of it" only restates what rent is.
      expect(
        isConcentratedPurchase(
          largestAmount: 35000,
          budget: 35000,
          transactionCount: 1,
        ),
        isFalse,
      );
    });

    test('a zero/unset budget never fires', () {
      expect(
        isConcentratedPurchase(
          largestAmount: 2800,
          budget: 0,
          transactionCount: 4,
        ),
        isFalse,
      );
    });
  });

  group('message text', () {
    test('projection wording carries the projected total and the budget', () {
      final projected = projectedSpend(4000, 10, 30);
      expect(
        buildProjectionText(
          categoryName: 'Shopping',
          budget: 8000,
          projected: projected,
          pctOver: projectedOverBudgetPercent(8000, projected),
        ),
        'At your current rate you will finish the month at about Rs. 12000 on '
        'Shopping — roughly 50% above your Rs. 8000 budget.',
      );
    });

    test('shortfall wording carries both the charges and what is left', () {
      expect(
        buildRecurringShortfallText(
          categoryName: 'Utilities',
          upcomingRecurring: 2400,
          remaining: remainingBudget(5000, 4200),
        ),
        'Rs. 2400 of recurring Utilities charges are due before month end, '
        'but only Rs. 800 of your budget remains.',
      );
    });

    test('large-purchase wording states the remaining amount', () {
      expect(
        buildConcentrationText(
          categoryName: 'Entertainment',
          largestAmount: 2325,
          budget: 2500,
          remaining: remainingBudget(2500, 1800),
        ),
        'A single Rs. 2325 purchase used 93% of your Entertainment budget. '
        'Rs. 700 is left for the rest of the month.',
      );
    });
  });
}
