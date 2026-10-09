import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/bobst.dart';
import '../theme/busyness_colors.dart';
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
                        const BrandMark(),
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
                          '${_thousands(building.occupancy)} people  ·  '
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
                        const SizedBox(height: 40),
                        Text(
                          'BEST SPOTS RIGHT NOW',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: onColor.withValues(alpha: 0.85),
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (status.bestQuiet case final area?)
                          _SpotCard(kind: 'To focus', area: area),
                        if (status.bestTalkative case final area?)
                          _SpotCard(kind: 'To talk', area: area),
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

class _SpotCard extends StatelessWidget {
  const _SpotCard({required this.kind, required this.area});

  final String kind;
  final Area area;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kind,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  area.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colorFor(area.busyness),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
            ),
            child: Text(
              area.busyness.label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _thousands(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
