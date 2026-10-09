import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/bobst.dart';
import '../theme/busyness_colors.dart';

/// Bobst as a stack of floors you can spin, tilt and zoom.
///
/// At rest it's a flat front-on view where each floor is one colour (its
/// overall busyness). Touching it eases into a perspective 3D view and splits
/// each floor into its areas around the atrium. Releasing near the front snaps
/// back to flat. Tapping a floor slides it out so its areas are easy to read.
///
/// Drawn with plain canvas maths (no 3D engine), so it's light and identical
/// on every platform.
class BuildingView extends StatefulWidget {
  const BuildingView({
    super.key,
    required this.floors,
    required this.onSelectionChanged,
  });

  final List<Floor> floors;

  /// Called with the selected floor id and, if an area was tapped, its id.
  final void Function(String? floorId, String? areaId) onSelectionChanged;

  @override
  State<BuildingView> createState() => BuildingViewState();
}

class BuildingViewState extends State<BuildingView>
    with TickerProviderStateMixin {
  // How far into 3D we are: 0 = flat front view, 1 = full 3D.
  double _depth = 0;
  double _yaw = 0;
  double _tilt = 0; // on top of the automatic tilt that comes with 3D
  double _zoom = 1;

  // Camera transitions (into 3D, back to flat).
  late final AnimationController _camera = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..addListener(_onCameraTick);
  _Pose? _from;
  _Pose? _to;

  // Momentum after a flick.
  late final Ticker _spin = createTicker(_onSpinTick);
  double _spinVelocity = 0; // radians per second
  Duration? _lastSpinTick;

  // Selected floor slides out of the stack.
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  String? _selectedFloor;
  String? _selectedArea;
  String? _slidFloor; // stays set while a deselected floor slides back in

  double _zoomAtGestureStart = 1;
  final _hits = <_Hit>[];

  bool get isFlat => _depth == 0 && !_camera.isAnimating;

  @override
  void dispose() {
    _camera.dispose();
    _spin.dispose();
    _slide.dispose();
    super.dispose();
  }

  // Camera ------------------------------------------------------------------

  void _onCameraTick() {
    final from = _from, to = _to;
    if (from == null || to == null) return;
    final t = Curves.easeInOutCubic.transform(_camera.value);
    setState(() {
      _depth = _lerp(from.depth, to.depth, t);
      if (to.moveCamera) {
        _yaw = _lerp(from.yaw, to.yaw, t);
        _tilt = _lerp(from.tilt, to.tilt, t);
        _zoom = _lerp(from.zoom, to.zoom, t);
      }
    });
  }

  void _animateTo(_Pose to) {
    _from = _Pose(_depth, _yaw, _tilt, _zoom);
    _to = to;
    _camera.forward(from: 0);
  }

  /// Animate back to the flat 2D view.
  void flatten() {
    _spin.stop();
    _animateTo(_Pose(0, _nearestFront(_yaw), 0, 1, moveCamera: true));
  }

  void _maybeSnapFlat() {
    final offFront = (_yaw - _nearestFront(_yaw)).abs();
    if (offFront < 0.3 && _tilt.abs() < 0.2) flatten();
  }

  // Gestures ----------------------------------------------------------------

  void _onScaleStart(ScaleStartDetails d) {
    _spin.stop();
    _camera.stop();
    _zoomAtGestureStart = _zoom;
    if (_depth < 1) _animateTo(_Pose(1, _yaw, _tilt, _zoom));
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    setState(() {
      _yaw += d.focalPointDelta.dx * 0.012;
      _tilt = (_tilt + d.focalPointDelta.dy * 0.008).clamp(-_autoTilt, 0.75);
      if (d.pointerCount > 1) {
        _zoom = (_zoomAtGestureStart * d.scale).clamp(0.6, 3.0);
      }
    });
  }

  void _onScaleEnd(ScaleEndDetails d) {
    final v = d.velocity.pixelsPerSecond.dx * 0.012;
    if (d.pointerCount == 0 && v.abs() > 1.2) {
      _spinVelocity = v.clamp(-12.0, 12.0);
      _lastSpinTick = null;
      _spin.start();
    } else {
      _maybeSnapFlat();
    }
  }

  void _onSpinTick(Duration elapsed) {
    final last = _lastSpinTick;
    _lastSpinTick = elapsed;
    if (last == null) return;
    final dt = (elapsed - last).inMicroseconds / 1e6;
    setState(() {
      _yaw += _spinVelocity * dt;
      _spinVelocity *= math.pow(0.04, dt); // friction
    });
    if (_spinVelocity.abs() < 0.08) {
      _spin.stop();
      _maybeSnapFlat();
    }
  }

  void _onTapUp(TapUpDetails d) {
    _Hit? hit;
    for (final h in _hits.reversed) {
      if (h.path.contains(d.localPosition)) {
        hit = h;
        break;
      }
    }

    final floor = hit?.floor;
    if (floor == null) {
      _select(null, null); // tapped empty space or an untracked floor
    } else if (floor.id == _selectedFloor && _depth > 0.5) {
      _select(floor.id, hit!.area?.id); // drill into an area of the open floor
    } else {
      _select(floor.id, null);
    }
  }

  void _select(String? floorId, String? areaId) {
    if (floorId != _selectedFloor) {
      if (floorId == null) {
        _slide.reverse();
      } else {
        _slidFloor = floorId;
        _slide.forward(from: 0);
      }
    }
    setState(() {
      _selectedFloor = floorId;
      _selectedArea = areaId;
    });
    widget.onSelectionChanged(floorId, areaId);
  }

  // Build -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            onScaleEnd: _onScaleEnd,
            onTapUp: _onTapUp,
            child: AnimatedBuilder(
              animation: _slide,
              builder: (context, _) => CustomPaint(
                size: Size.infinite,
                painter: _BuildingPainter(
                  floors: {for (final f in widget.floors) f.id: f},
                  depth: _depth,
                  yaw: _yaw,
                  pitch: (_tilt + _autoTilt * _depth).clamp(-0.2, 1.25),
                  zoom: _zoom,
                  // Keep drawing the floor that's sliding back in.
                  selectedFloor:
                      _selectedFloor ?? (_slide.value > 0 ? _slidFloor : null),
                  selectedArea: _selectedArea,
                  slide: Curves.easeOutCubic.transform(_slide.value),
                  hits: _hits,
                  labelStyle: theme.textTheme.labelLarge!.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                  countStyle: theme.textTheme.bodySmall!.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  untrackedColor: theme.colorScheme.outlineVariant,
                  shadowColor: theme.colorScheme.shadow,
                  backgroundColor: theme.colorScheme.surface,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: AnimatedOpacity(
            opacity: _depth > 0.05 ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: _depth <= 0.05,
              child: IconButton.filledTonal(
                tooltip: 'Flat view',
                onPressed: flatten,
                icon: const Icon(Icons.view_agenda_outlined),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Tilt applied automatically when going 3D, so the floor tops show.
const _autoTilt = 0.5;

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// Nearest yaw that faces the front (multiples of a full turn).
double _nearestFront(double yaw) =>
    (yaw / (2 * math.pi)).roundToDouble() * 2 * math.pi;

class _Pose {
  const _Pose(
    this.depth,
    this.yaw,
    this.tilt,
    this.zoom, {
    this.moveCamera = false,
  });

  final double depth, yaw, tilt, zoom;
  final bool moveCamera;
}

/// Every level of Bobst bottom to top, including ones we don't track, so the
/// building looks right.
const _levels = [
  _Level('LL2', 'LL2'),
  _Level('LL1', 'LL1'),
  _Level('1', '1'),
  _Level('M', 'M', height: 0.3),
  _Level('2', '2'),
  _Level('3', '3'),
  _Level('4', '4'),
  _Level('5', '5'),
  _Level('6', '6'),
  _Level('7', '7'),
  _Level('8', '8'),
  _Level('9', '9'),
  _Level('10', '10'),
  _Level('11', '11'),
  _Level('12', '12'),
];

const _gap = 0.22;
const _width = 4.0; // footprint: a 4x4 grid of blocks around a 2x2 atrium
const _slideDistance = 2.4;
const _liftAbove = 0.6;

class _Level {
  const _Level(this.id, this.label, {this.height = 0.6});

  final String id;
  final String label;
  final double height;
}

class _V {
  const _V(this.x, this.y, this.z);

  final double x, y, z;

  _V operator +(_V o) => _V(x + o.x, y + o.y, z + o.z);
}

/// One block of a floor: a cell of the ring around the atrium.
class _Cell {
  _Cell(this.min, this.max, this.floor, this.area);

  final _V min, max;
  final Floor? floor;
  final Area? area;

  _V get center =>
      _V((min.x + max.x) / 2, (min.y + max.y) / 2, (min.z + max.z) / 2);
}

class _Hit {
  _Hit(this.path, this.floor, this.area);

  final Path path;
  final Floor? floor;
  final Area? area;
}

class _BuildingPainter extends CustomPainter {
  _BuildingPainter({
    required this.floors,
    required this.depth,
    required this.yaw,
    required this.pitch,
    required this.zoom,
    required this.selectedFloor,
    required this.selectedArea,
    required this.slide,
    required this.hits,
    required this.labelStyle,
    required this.countStyle,
    required this.untrackedColor,
    required this.shadowColor,
    required this.backgroundColor,
  });

  final Map<String, Floor> floors;
  final double depth, yaw, pitch, zoom, slide;
  final String? selectedFloor;
  final String? selectedArea;
  final List<_Hit> hits;
  final TextStyle labelStyle, countStyle;
  final Color untrackedColor, shadowColor, backgroundColor;

  late double _cosY, _sinY, _cosP, _sinP, _height, _focal, _camDist;
  late Offset _center;

  @override
  void paint(Canvas canvas, Size size) {
    hits.clear();
    _cosY = math.cos(yaw);
    _sinY = math.sin(yaw);
    _cosP = math.cos(pitch);
    _sinP = math.sin(pitch);

    final selectedIndex = _levels.indexWhere((l) => l.id == selectedFloor);
    final cells = <_Cell>[];
    final levelY = <String, double>{};
    var y = 0.0;
    for (var i = 0; i < _levels.length; i++) {
      final level = _levels[i];
      levelY[level.id] = y;
      cells.addAll(_cellsFor(level, y + _liftFor(i, selectedIndex)));
      y += level.height + _gap;
    }
    _height = y - _gap;

    // Fit: flat view leaves room for labels; 3D fits a bounding sphere.
    final radius = math.sqrt(
      math.pow(_height / 2, 2) + 2 * math.pow(_width / 2, 2),
    );
    final flatScale = math.min(
      (size.width - 2 * 96) / _width,
      size.height * 0.92 / _height,
    );
    final roundScale = math.min(size.width, size.height) * 0.47 / radius;
    final scale = _lerp(flatScale, roundScale, depth) * zoom;
    // Perspective eases in with 3D; at depth 0 the camera is effectively at
    // infinity, so the flat view has no distortion.
    _camDist = _lerp(4000, radius * 3.2, depth);
    _focal = scale * _camDist;
    _center = Offset(size.width / 2, size.height / 2);

    if (depth > 0) _paintShadow(canvas);

    // Painter's algorithm: farthest blocks first.
    cells.sort((a, b) => _distance(b.center).compareTo(_distance(a.center)));
    for (final cell in cells) {
      _paintCell(canvas, cell);
    }

    if (depth < 0.5) _paintLabels(canvas, levelY, 1 - depth * 2, selectedIndex);
  }

  /// Floors above the selected one lift to open a gap.
  double _liftFor(int index, int selectedIndex) =>
      selectedIndex >= 0 && index > selectedIndex ? _liftAbove * slide : 0;

  List<_Cell> _cellsFor(_Level level, double y0) {
    final floor = floors[level.id];
    final bySide = <Side, Area>{
      for (final area in floor?.areas ?? const <Area>[])
        for (final side in area.sides) side: area,
    };
    // The selected floor slides towards the camera (only in 3D).
    final out = level.id == selectedFloor
        ? _slideDistance * slide * depth
        : 0.0;
    final offset = _V(-_sinY * out, 0, _cosY * out);

    final cells = <_Cell>[];
    for (var gz = 0; gz < 4; gz++) {
      for (var gx = 0; gx < 4; gx++) {
        if (gx > 0 && gx < 3 && gz > 0 && gz < 3) continue; // atrium
        final side = gz == 0
            ? Side.north
            : gz == 3
            ? Side.south
            : gx == 0
            ? Side.west
            : Side.east;
        cells.add(
          _Cell(
            _V(gx - 2.0, y0, gz - 2.0) + offset,
            _V(gx - 1.0, y0 + level.height, gz - 1.0) + offset,
            floor,
            bySide[side],
          ),
        );
      }
    }
    return cells;
  }

  // Camera maths ------------------------------------------------------------

  /// World → camera space. Camera sits on +z looking at the building centre.
  _V _view(_V p) {
    final x = p.x, y = p.y - _height / 2, z = p.z;
    final x1 = x * _cosY + z * _sinY;
    final z1 = -x * _sinY + z * _cosY;
    return _V(x1, y * _cosP - z1 * _sinP, z1 * _cosP + y * _sinP);
  }

  _V _viewDir(_V n) {
    final x1 = n.x * _cosY + n.z * _sinY;
    final z1 = -n.x * _sinY + n.z * _cosY;
    return _V(x1, n.y * _cosP - z1 * _sinP, z1 * _cosP + n.y * _sinP);
  }

  Offset _project(_V p) {
    final v = _view(p);
    final s = _focal / (_camDist - v.z);
    return Offset(_center.dx + v.x * s, _center.dy - v.y * s);
  }

  double _distance(_V p) {
    final v = _view(p);
    return math.sqrt(v.x * v.x + v.y * v.y + math.pow(_camDist - v.z, 2));
  }

  // Drawing -----------------------------------------------------------------

  void _paintShadow(Canvas canvas) {
    const r = _width / 2 + 0.5;
    final ground = [
      _project(const _V(-r, -0.15, -r)),
      _project(const _V(r, -0.15, -r)),
      _project(const _V(r, -0.15, r)),
      _project(const _V(-r, -0.15, r)),
    ];
    canvas.drawPath(
      Path()..addPolygon(ground, true),
      Paint()
        ..color = shadowColor.withValues(alpha: 0.18 * depth)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
  }

  Color _colorOf(_Cell cell) {
    final floor = cell.floor;
    if (floor == null) return untrackedColor;
    final floorColor = colorFor(floor.busyness);
    final area = cell.area;
    final areaColor = area != null
        ? colorFor(area.busyness)
        : Color.lerp(floorColor, untrackedColor, 0.75)!;
    var color = Color.lerp(floorColor, areaColor, depth)!;
    if (selectedArea != null && floor.id == selectedFloor) {
      // Spotlight the tapped area within the open floor.
      if (area?.id != selectedArea) {
        color = Color.lerp(color, untrackedColor, 0.5)!;
      }
    }
    return color;
  }

  /// How far to fade a block into the background: everything except the
  /// selected floor fades. Kept opaque so blocks don't show through.
  double _fadeOf(_Cell cell) {
    if (selectedFloor == null || cell.floor?.id == selectedFloor) return 0;
    return 0.72 * slide;
  }

  void _paintCell(Canvas canvas, _Cell c) {
    final base = Color.lerp(_colorOf(c), backgroundColor, _fadeOf(c))!;
    final a = c.min, b = c.max;
    final faces = <(_V, List<_V>)>[
      // (outward normal, corners going round the face)
      (
        const _V(0, 1, 0),
        [
          _V(a.x, b.y, a.z),
          _V(b.x, b.y, a.z),
          _V(b.x, b.y, b.z),
          _V(a.x, b.y, b.z),
        ],
      ),
      (
        const _V(0, -1, 0),
        [
          _V(a.x, a.y, a.z),
          _V(b.x, a.y, a.z),
          _V(b.x, a.y, b.z),
          _V(a.x, a.y, b.z),
        ],
      ),
      (
        const _V(0, 0, 1),
        [
          _V(a.x, b.y, b.z),
          _V(b.x, b.y, b.z),
          _V(b.x, a.y, b.z),
          _V(a.x, a.y, b.z),
        ],
      ),
      (
        const _V(0, 0, -1),
        [
          _V(a.x, b.y, a.z),
          _V(b.x, b.y, a.z),
          _V(b.x, a.y, a.z),
          _V(a.x, a.y, a.z),
        ],
      ),
      (
        const _V(1, 0, 0),
        [
          _V(b.x, b.y, a.z),
          _V(b.x, b.y, b.z),
          _V(b.x, a.y, b.z),
          _V(b.x, a.y, a.z),
        ],
      ),
      (
        const _V(-1, 0, 0),
        [
          _V(a.x, b.y, a.z),
          _V(a.x, b.y, b.z),
          _V(a.x, a.y, b.z),
          _V(a.x, a.y, a.z),
        ],
      ),
    ];

    for (final (n, corners) in faces) {
      // Back-face cull against the actual camera position (perspective).
      final nv = _viewDir(n);
      final fc = _view(
        _V(
          (corners[0].x + corners[2].x) / 2,
          (corners[0].y + corners[2].y) / 2,
          (corners[0].z + corners[2].z) / 2,
        ),
      );
      final toCam = _V(-fc.x, -fc.y, _camDist - fc.z);
      if (nv.x * toCam.x + nv.y * toCam.y + nv.z * toCam.z <= 1e-6) continue;

      // Light from upper left of the camera, so the view always reads well.
      const lx = -0.42, ly = 0.72, lz = 0.55;
      final diffuse = math.max(0.0, nv.x * lx + nv.y * ly + nv.z * lz);
      final shade = _lerp(1, 0.58 + 0.42 * diffuse, depth);
      final color = Color.lerp(Colors.black, base, shade)!;

      final points = corners.map(_project).toList();
      final path = Path()..addPolygon(points, true);

      // Glassy sheen: side faces get lighter towards their top edge.
      final isSide = n.y == 0;
      final paint = Paint()..color = color;
      if (isSide && depth > 0) {
        final top = Offset.lerp(points[0], points[1], 0.5)!;
        final bottom = Offset.lerp(points[2], points[3], 0.5)!;
        paint.shader = ui.Gradient.linear(top, bottom, [
          Color.lerp(color, Colors.white, 0.22 * depth)!,
          color,
        ]);
      }
      canvas.drawPath(path, paint);
      // Hairline in the same paint (gradient included) hides seams between
      // neighbouring blocks.
      canvas.drawPath(
        path,
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7,
      );
      hits.add(_Hit(path, c.floor, c.area));
    }
  }

  void _paintLabels(
    Canvas canvas,
    Map<String, double> levelY,
    double opacity,
    int selectedIndex,
  ) {
    for (var i = 0; i < _levels.length; i++) {
      final level = _levels[i];
      final mid =
          levelY[level.id]! + _liftFor(i, selectedIndex) + level.height / 2;
      final left = _project(_V(-_width / 2, mid, _width / 2));
      final right = _project(_V(_width / 2, mid, _width / 2));
      final floor = floors[level.id];
      final dim = selectedFloor != null && level.id != selectedFloor;
      final alpha = opacity * (floor == null || dim ? 0.4 : 1);

      _text(
        canvas,
        level.label,
        labelStyle.copyWith(color: labelStyle.color!.withValues(alpha: alpha)),
        Offset(left.dx - 10, left.dy),
        alignRight: true,
      );
      if (floor != null) {
        _text(
          canvas,
          '${floor.occupancy}',
          countStyle.copyWith(
            color: countStyle.color!.withValues(alpha: alpha),
          ),
          Offset(right.dx + 10, right.dy),
        );
      }
    }
  }

  void _text(
    Canvas canvas,
    String text,
    TextStyle style,
    Offset anchor, {
    bool alignRight = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = alignRight ? anchor.dx - tp.width : anchor.dx;
    tp.paint(canvas, Offset(dx, anchor.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_BuildingPainter old) => true;
}
