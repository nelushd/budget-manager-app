import 'package:flutter_test/flutter_test.dart';

import 'package:budget_manager_app/utils/budget_insight_engine.dart';

void main() {
  group('percentageAboveBudget', () {
    test('budget 25,000 / actual 30,000 -> 20% over', () {
      expect(percentageAboveBudget(25000, 30000), closeTo(20, 0.001));
    });
  });

  group('isAboveBudget', () {
    test('Test 1: actual > budget -> true', () {
      expect(isAboveBudget(25000, 30000), isTrue);
    });

    test('Test 2: actual == budget -> false (no overspending warning)', () {
      expect(isAboveBudget(25000, 25000), isFalse);
    });

    test('Test 3: actual < budget -> false (no "under budget" message either)', () {
      expect(isAboveBudget(25000, 20000), isFalse);
    });

    test('Test 4: multiple categories -> only the over-budget ones trigger', () {
      final results = {
        'Food': isAboveBudget(25000, 30000),
        'Transport': isAboveBudget(10000, 8000),
        'Shopping': isAboveBudget(15000, 18000),
      };

      expect(results['Food'], isTrue);
      expect(results['Transport'], isFalse);
      expect(results['Shopping'], isTrue);
    });

    test('a zero/unset budget never triggers an insight', () {
      expect(isAboveBudget(0, 500), isFalse);
    });
  });

  group('buildRecommendationText', () {
    test('matches the expected wording and rounds the percentage', () {
      final text = buildRecommendationText(
        categoryName: 'Food',
        budget: 25000,
        actual: 30000,
        pctOver: percentageAboveBudget(25000, 30000),
      );

      expect(
        text,
        'You are spending approximately 20% above your Food budget. '
        'Try to keep your Food expenditure within Rs. 25000 next month.',
      );
    });
  });
}
