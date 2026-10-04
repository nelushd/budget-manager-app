import 'package:flutter/material.dart';
import '../../constants/colors.dart';

class CircularProgressRing extends StatelessWidget {
  final double percentage;
  final double size;
  final double strokeWidth;
  final Color color;
  final Color trackColor;
  final Widget? child;

  const CircularProgressRing({
    super.key,
    required this.percentage,
    this.size = 120,
    this.strokeWidth = 10,
    this.color = AppColors.primary,
    this.trackColor = const Color(0xFFE2E8F0),
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final pct = percentage.clamp(0.0, 100.0) / 100.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: strokeWidth,
              valueColor: AlwaysStoppedAnimation<Color>(trackColor),
            ),
          ),
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: pct,
              strokeWidth: strokeWidth,
              strokeCap: StrokeCap.round,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              backgroundColor: Colors.transparent,
            ),
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}
