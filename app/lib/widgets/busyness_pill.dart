import 'package:flutter/material.dart';

import '../models/bobst.dart';
import '../theme/busyness_colors.dart';

class BusynessPill extends StatelessWidget {
  const BusynessPill({super.key, required this.busyness});

  final Busyness busyness;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorFor(busyness),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        busyness.label,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class FullnessBar extends StatelessWidget {
  const FullnessBar({
    super.key,
    required this.fullness,
    required this.busyness,
    this.height = 8,
  });

  final double fullness;
  final Busyness busyness;
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = colorFor(busyness);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: LinearProgressIndicator(
        value: fullness,
        minHeight: height,
        color: color,
        backgroundColor: color.withValues(alpha: 0.15),
      ),
    );
  }
}
