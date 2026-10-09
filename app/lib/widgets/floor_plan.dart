import 'package:flutter/material.dart';

import '../models/bobst.dart';
import '../theme/busyness_colors.dart';

// Bobst's footprint: a square ring of floor around a central atrium.
const _outer = 2.6; // half-width of the building
const _inner = 1.05; // half-width of the atrium

/// Overhead view of one floor: a block per side of the atrium, each filled
/// with how busy it is.
///
/// The same widget is the thumbnail on a floor card ([detail] = 0) and the
/// full plan on the floor page ([detail] = 1); the hero flight between them
/// animates [detail], so labels fade in as it grows.
class FloorPlanDiagram extends StatelessWidget {
  const FloorPlanDiagram({
    super.key,
    required this.floor,
    this.detail = 0,
    this.selectedAreaId,
    this.onTapArea,
  });

  final Floor floor;
  final double detail;
  final String? selectedAreaId;
  final ValueChanged<String?>? onTapArea;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, box) {
          // Always a square, even if squeezed mid-animation.
          final s = box.maxHeight.isFinite
              ? (box.maxWidth < box.maxHeight ? box.maxWidth : box.maxHeight)
              : box.maxWidth;
          final band = s * (_outer - _inner) / (2 * _outer);
          final gap = s * 0.025;
          final radius = s * 0.05;

          final bySide = <Side, Area>{
            for (final area in floor.areas)
              for (final side in area.sides) side: area,
          };

          Widget block(Side side, Rect r) => Positioned.fromRect(
            rect: r,
            child: _Block(
              area: bySide[side],
              radius: radius,
              detail: detail,
              selected:
                  selectedAreaId != null && bySide[side]?.id == selectedAreaId,
              dimmed:
                  selectedAreaId != null && bySide[side]?.id != selectedAreaId,
              onTap: onTapArea == null || bySide[side] == null
                  ? null
                  : () {
                      final id = bySide[side]!.id;
                      onTapArea!(id == selectedAreaId ? null : id);
                    },
            ),
          );

          final middle = s - 2 * band - gap;
          return Center(
            child: SizedBox.square(
              dimension: s,
              child: Stack(
                children: [
                  block(Side.north, Rect.fromLTWH(0, 0, s, band - gap / 2)),
                  block(
                    Side.south,
                    Rect.fromLTWH(0, s - band + gap / 2, s, band - gap / 2),
                  ),
                  block(
                    Side.west,
                    Rect.fromLTWH(0, band + gap / 2, band - gap / 2, middle),
                  ),
                  block(
                    Side.east,
                    Rect.fromLTWH(
                      s - band + gap / 2,
                      band + gap / 2,
                      band - gap / 2,
                      middle,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({
    required this.area,
    required this.radius,
    required this.detail,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  final Area? area;
  final double radius;
  final double detail;
  final bool selected;
  final bool dimmed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final area = this.area;
    final fill = area == null
        ? theme.colorScheme.surfaceContainerHighest
        : colorFor(area.busyness);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: dimmed ? 0.35 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: fill.withValues(alpha: 0.45),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: onTap,
            child: detail <= 0 || area == null
                ? const SizedBox.expand()
                : Opacity(
                    opacity: Curves.easeIn.transform(detail),
                    child: _Label(area: area),
                  ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.area});

  final Area area;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  area.name,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                Text(
                  area.busyness.label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
