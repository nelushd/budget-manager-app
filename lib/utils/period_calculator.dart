/// Calendar-aligned period windows for reusable budgets/recurring status.
///
/// Budgets don't reset — only the spend calculation rolls forward each
/// period. This computes the [start, end] window for a given period type
/// and reference date, entirely client-side, so nothing needs to be stored.
class PeriodWindow {
  final DateTime start;
  final DateTime end;

  const PeriodWindow(this.start, this.end);

  bool contains(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return !d.isBefore(start) && !d.isAfter(end);
  }
}

class PeriodCalculator {
  PeriodCalculator._();

  static const List<String> periods = [
    'daily',
    'weekly',
    'monthly',
    'quarterly',
    'yearly',
  ];

  static PeriodWindow windowFor(String period, DateTime reference) {
    switch (period) {
      case 'daily':
        final day = DateTime(reference.year, reference.month, reference.day);
        return PeriodWindow(day, day);

      case 'weekly':
        final day = DateTime(reference.year, reference.month, reference.day);
        final start = day.subtract(Duration(days: day.weekday - 1));
        final end = start.add(const Duration(days: 6));
        return PeriodWindow(start, end);

      case 'quarterly':
        final quarterIndex = (reference.month - 1) ~/ 3;
        final startMonth = quarterIndex * 3 + 1;
        final start = DateTime(reference.year, startMonth, 1);
        final end = DateTime(reference.year, startMonth + 3, 0);
        return PeriodWindow(start, end);

      case 'yearly':
        return PeriodWindow(
          DateTime(reference.year, 1, 1),
          DateTime(reference.year, 12, 31),
        );

      case 'monthly':
      default:
        final start = DateTime(reference.year, reference.month, 1);
        final end = DateTime(reference.year, reference.month + 1, 0);
        return PeriodWindow(start, end);
    }
  }

  /// Moves [reference] forward/backward by [steps] whole periods. Returns a
  /// date guaranteed to fall inside the shifted period (safe to pass into
  /// [windowFor]).
  static DateTime shift(String period, DateTime reference, int steps) {
    switch (period) {
      case 'daily':
        return DateTime(reference.year, reference.month, reference.day + steps);
      case 'weekly':
        return DateTime(
          reference.year,
          reference.month,
          reference.day + steps * 7,
        );
      case 'quarterly':
        return DateTime(reference.year, reference.month + steps * 3, 1);
      case 'yearly':
        return DateTime(reference.year + steps, reference.month, 1);
      case 'monthly':
      default:
        return DateTime(reference.year, reference.month + steps, 1);
    }
  }

  /// Clips [window] to the budget's own active range. Returns null if the
  /// window falls entirely outside [startBound]/[endBound] (e.g. navigating
  /// to a period before the budget existed or after it ended).
  static PeriodWindow? clip(
    PeriodWindow window, {
    DateTime? startBound,
    DateTime? endBound,
  }) {
    var start = window.start;
    var end = window.end;

    if (startBound != null && start.isBefore(startBound)) {
      start = startBound;
    }
    if (endBound != null && end.isAfter(endBound)) {
      end = endBound;
    }

    if (start.isAfter(end)) return null;
    return PeriodWindow(start, end);
  }

  /// Walks back [count] whole periods before (and not including) the period
  /// containing [reference], oldest first. Used for spend history / the
  /// budget AI advisor's heuristic.
  static List<PeriodWindow> previousPeriods(
    String period,
    DateTime reference,
    int count,
  ) {
    final windows = <PeriodWindow>[];
    for (var i = count; i >= 1; i--) {
      final ref = shift(period, reference, -i);
      windows.add(windowFor(period, ref));
    }
    return windows;
  }

  static String formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static DateTime parseDate(String date) {
    return DateTime.parse(date);
  }
}
