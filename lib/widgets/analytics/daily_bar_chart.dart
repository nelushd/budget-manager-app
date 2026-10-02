import 'package:flutter/material.dart';

import '../../constants/colors.dart';

class DailyBarPoint {
  final int day;
  final double income;
  final double expense;

  const DailyBarPoint({required this.day, required this.income, required this.expense});
}

/// Paired daily income/expense bars across a date window — hand-rolled to
/// match the app's existing convention of small custom-painted charts
/// rather than pulling in a charting package for one shape.
class DailyBarChart extends StatelessWidget {
  final List<DailyBarPoint> points;
  final double height;

  const DailyBarChart({super.key, required this.points, this.height = 160});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text('No data for this period.', style: TextStyle(color: Colors.grey[500])),
        ),
      );
    }

    final maxValue = points.fold<double>(
      0,
      (max, p) => [max, p.income, p.expense].reduce((a, b) => a > b ? a : b),
    );

    return SizedBox(
      height: height,
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final point in points)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: _Bar(
                              color: AppColors.error,
                              fraction: maxValue <= 0 ? 0 : point.expense / maxValue,
                            ),
                          ),
                          const SizedBox(width: 1),
                          Expanded(
                            child: _Bar(
                              color: AppColors.success,
                              fraction: maxValue <= 0 ? 0 : point.income / maxValue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final point in points)
                Expanded(
                  child: (point.day == 1 || point.day % 5 == 0)
                      ? Text(
                          '${point.day}',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                        )
                      : const SizedBox.shrink(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final Color color;
  final double fraction;

  const _Bar({required this.color, required this.fraction});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: fraction.clamp(0.0, 1.0) == 0 ? 0.01 : fraction.clamp(0.0, 1.0),
      alignment: Alignment.bottomCenter,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
        ),
      ),
    );
  }
}
