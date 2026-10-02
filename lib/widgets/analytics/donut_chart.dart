import 'dart:math' as math;

import 'package:flutter/material.dart';

class DonutSlice {
  final Color color;
  final double value;

  const DonutSlice({required this.color, required this.value});
}

/// A simple hand-rolled donut chart — one arc per slice, proportional to
/// its share of the total. Matches the app's existing convention of
/// hand-rolled circular widgets (see CircularProgressRing) instead of
/// pulling in a charting package for a single chart shape.
class DonutChart extends StatelessWidget {
  final List<DonutSlice> slices;
  final double size;
  final double strokeWidth;
  final Widget? center;

  const DonutChart({
    super.key,
    required this.slices,
    this.size = 220,
    this.strokeWidth = 34,
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _DonutPainter(slices: slices, strokeWidth: strokeWidth),
          ),
          ?center,
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<DonutSlice> slices;
  final double strokeWidth;

  _DonutPainter({required this.slices, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<double>(0, (sum, s) => sum + s.value);
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(strokeWidth / 2);

    if (total <= 0) {
      final paint = Paint()
        ..color = const Color(0xFFE5E7EB)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawArc(arcRect, 0, 2 * math.pi, false, paint);
      return;
    }

    var start = -math.pi / 2;
    for (final slice in slices) {
      if (slice.value <= 0) continue;
      final sweep = (slice.value / total) * 2 * math.pi;
      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = slices.length > 1 ? StrokeCap.butt : StrokeCap.round;
      canvas.drawArc(arcRect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.slices != slices || oldDelegate.strokeWidth != strokeWidth;
  }
}
