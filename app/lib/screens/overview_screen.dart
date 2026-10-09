import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/bobst.dart';
import '../theme/busyness_colors.dart';
import '../util/format.dart';
import '../widgets/brand_mark.dart';
import '../widgets/updated_label.dart';

class OverviewScreen extends StatelessWidget {
  const OverviewScreen({
    super.key,
    required this.status,
    required this.onRefresh,
  });

  final BobstStatus status;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final building = status.building;
    final color = colorFor(building.busyness);
    final theme = Theme.of(context);
    const onColor = Colors.white;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // White status bar icons over the coloured background.
      value: SystemUiOverlayStyle.light,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color, Color.lerp(color, Colors.black, 0.35)!],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: onRefresh,
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: SafeArea(
                  child: Padding(
                    // Bottom padding keeps content clear of the floating tab bar.
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            BrandMark(cutoutColor: color),
                            const Spacer(),
                            if (status.simulated) const _SimulatedBadge(),
                          ],
                        ),
                        SizedBox(height: constraints.maxHeight * 0.14),
                        Text(
                          'BOBST IS',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: onColor.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            building.busyness.label.toUpperCase(),
                            style: theme.textTheme.displayLarge?.copyWith(
                              fontSize: 76,
                              height: 1.0,
                              fontWeight: FontWeight.w900,
                              color: onColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          '${thousands(building.occupancy)} people  ·  '
                          '${(building.fullness * 100).round()}% full',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: onColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        UpdatedLabel(
                          updatedAt: status.updatedAt,
                          color: onColor.withValues(alpha: 0.75),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SimulatedBadge extends StatelessWidget {
  const _SimulatedBadge();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.science_outlined, size: 16, color: Colors.white),
        const SizedBox(width: 4),
        Text(
          'Simulated data',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Colors.white),
        ),
      ],
    );
  }
}
