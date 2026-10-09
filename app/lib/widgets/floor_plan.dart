import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/bobst.dart';
import '../theme/busyness_colors.dart';
import 'building_view.dart' show buildingInner, buildingOuter;

/// Streets around Bobst, for orientation on the floor plan.
const _north = 'Washington Square Park';
const _south = 'West 3rd Street';
const _west = 'LaGuardia Place';
const _east = 'Schwartz Plaza';

/// Space reserved around the plan for street names.
const planStreetTop = 28.0;
const planStreetSide = 24.0;

/// Where the square floor plan sits inside a [FloorPlan] of the given width.
/// The 3D view lands the opened floor on exactly this rect so the hand-off
/// from building to plan is seamless.
Rect floorPlanRect(double width) {
  final side = width - 2 * planStreetSide;
  return Rect.fromLTWH(planStreetSide, planStreetTop, side, side);
}

/// Overhead plan of one floor: four sides around the open atrium, each
/// coloured and labelled with how busy it is, with streets for orientation.
class FloorPlan extends StatefulWidget {
  const FloorPlan({
    super.key,
    required this.floor,
    required this.selectedAreaId,
    required this.onTapArea,
  });

  final Floor floor;
  final String? selectedAreaId;
  final ValueChanged<String?> onTapArea;

  @override
  State<FloorPlan> createState() => _FloorPlanState();
}

class _FloorPlanState extends State<FloorPlan>
    with SingleTickerProviderStateMixin {
  // Cards settle in one after another when the plan appears.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..forward();

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final streetStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final plan = floorPlanRect(width);
        final s = plan.width;
        final band = s * (buildingOuter - buildingInner) / (2 * buildingOuter);
        const g = 8.0; // gap between cards

        final bySide = <Side, Area>{
          for (final area in widget.floor.areas)
            for (final side in area.sides) side: area,
        };

        Widget card(int order, Side side, Rect r) => Positioned.fromRect(
          rect: r.shift(plan.topLeft),
          child: _Entrance(
            animation: CurvedAnimation(
              parent: _intro,
              curve: Interval(
                order * 0.12,
                0.55 + order * 0.12,
                curve: Curves.easeOutCubic,
              ),
            ),
            child: _SideCard(
              side: side,
              area: bySide[side],
              selected:
                  widget.selectedAreaId != null &&
                  bySide[side]?.id == widget.selectedAreaId,
              dimmed:
                  widget.selectedAreaId != null &&
                  bySide[side]?.id != widget.selectedAreaId,
              onTap: () {
                final id = bySide[side]?.id;
                widget.onTapArea(id == widget.selectedAreaId ? null : id);
              },
            ),
          ),
        );

        return SizedBox(
          width: width,
          height: plan.bottom + planStreetTop,
          child: Stack(
            children: [
              // Streets.
              Positioned(
                top: 4,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.north,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(_north, style: streetStyle),
                  ],
                ),
              ),
              Positioned(
                top: plan.bottom + 6,
                left: 0,
                right: 0,
                child: Text(
                  _south,
                  style: streetStyle,
                  textAlign: TextAlign.center,
                ),
              ),
              Positioned(
                left: 0,
                top: plan.top,
                width: planStreetSide,
                height: s,
                child: Center(
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Text(_west, style: streetStyle),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                top: plan.top,
                width: planStreetSide,
                height: s,
                child: Center(
                  child: RotatedBox(
                    quarterTurns: 1,
                    child: Text(_east, style: streetStyle),
                  ),
                ),
              ),
              // Floor.
              card(0, Side.north, Rect.fromLTWH(0, 0, s, band - g / 2)),
              card(
                1,
                Side.west,
                Rect.fromLTWH(0, band + g / 2, band - g / 2, s - 2 * band - g),
              ),
              card(
                1,
                Side.east,
                Rect.fromLTWH(
                  s - band + g / 2,
                  band + g / 2,
                  band - g / 2,
                  s - 2 * band - g,
                ),
              ),
              card(
                2,
                Side.south,
                Rect.fromLTWH(0, s - band + g / 2, s, band - g / 2),
              ),
              Positioned.fromRect(
                rect: Rect.fromLTWH(
                  band + g / 2,
                  band + g / 2,
                  s - 2 * band - g,
                  s - 2 * band - g,
                ).shift(plan.topLeft),
                child: _Entrance(
                  animation: CurvedAnimation(
                    parent: _intro,
                    curve: const Interval(0.1, 0.7, curve: Curves.easeOut),
                  ),
                  child: const _Atrium(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Fades and gently scales a child in.
class _Entrance extends StatelessWidget {
  const _Entrance({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Opacity(
        opacity: animation.value,
        child: Transform.scale(
          scale: 0.94 + 0.06 * animation.value,
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _SideCard extends StatelessWidget {
  const _SideCard({
    required this.side,
    required this.area,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  final Side side;
  final Area? area;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final area = this.area;
    final sideName = side.name.toUpperCase();

    final Color accent;
    final Color fill;
    final Color ink;
    if (area == null) {
      accent = theme.colorScheme.outlineVariant;
      fill = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
      ink = theme.colorScheme.onSurfaceVariant;
    } else {
      accent = colorFor(area.busyness);
      fill = Color.alphaBlend(
        accent.withValues(alpha: 0.13),
        theme.colorScheme.surface,
      );
      ink = _deepen(accent);
    }

    final name = area?.name.toUpperCase();
    final heading = name == null || name == sideName
        ? sideName
        : name.startsWith(sideName)
        ? name
        : '$sideName · $name';

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: dimmed ? 0.45 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent, width: selected ? 3 : 1.6),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: accent.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: area == null ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: LayoutBuilder(
                builder: (context, box) {
                  final narrow = box.maxWidth < 140;
                  final word =
                      (area == null
                              ? theme.textTheme.titleSmall
                              : narrow
                              ? theme.textTheme.titleMedium
                              : theme.textTheme.titleLarge)
                          ?.copyWith(
                            color: ink,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          );
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          heading,
                          maxLines: 1,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: ink.withValues(alpha: 0.85),
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        area?.busyness.label ?? 'No study space',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: word,
                      ),
                      if (area != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${area.occupancy} people',
                          maxLines: 1,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: ink.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Darker version of a busyness colour that stays readable on its own tint.
Color _deepen(Color c) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness(math.min(hsl.lightness, 0.34)).toColor();
}

/// The open atrium, looking down at the lobby's famous op-art marble floor.
class _Atrium extends StatelessWidget {
  const _Atrium();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: _LobbyFloorPainter()),
          // Soft inner shadow so it reads as a drop down to the lobby.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.45),
                ],
                stops: const [0.55, 1],
                radius: 0.85,
              ),
            ),
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Open atrium',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Lobby floor below',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tumbling-blocks pattern echoing Bobst's marble lobby floor.
class _LobbyFloorPainter extends CustomPainter {
  const _LobbyFloorPainter();

  static const _top = Color(0xFFE6DCC6);
  static const _left = Color(0xFFA8987A);
  static const _right = Color(0xFF4B4336);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _left);
    const r = 13.0; // cube edge on screen
    final w = r * math.sqrt(3); // width of one cube
    final top = Paint()..color = _top;
    final left = Paint()..color = _left;
    final right = Paint()..color = _right;

    var row = 0;
    for (var y = -r; y < size.height + r; y += r * 1.5) {
      final shift = row.isOdd ? w / 2 : 0.0;
      for (var x = -w + shift; x < size.width + w; x += w) {
        final c = Offset(x, y);
        final up = c + Offset(0, -r);
        final ul = c + Offset(-w / 2, -r / 2);
        final ur = c + Offset(w / 2, -r / 2);
        final dl = c + Offset(-w / 2, r / 2);
        final dr = c + Offset(w / 2, r / 2);
        final down = c + Offset(0, r);
        canvas
          ..drawPath(Path()..addPolygon([up, ur, c, ul], true), top)
          ..drawPath(Path()..addPolygon([ul, c, down, dl], true), left)
          ..drawPath(Path()..addPolygon([c, ur, dr, down], true), right);
      }
      row++;
    }
  }

  @override
  bool shouldRepaint(_LobbyFloorPainter old) => false;
}
