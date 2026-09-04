import 'dart:math';
import 'package:flutter/material.dart';

/// Paints a perspective-projected AR floor navigation path on the camera feed.
///
/// Simulates a path anchored to the physical floor using a pinhole camera
/// perspective model. No ARCore/ARKit required — looks like real AR because
/// objects converge to a vanishing point proportional to distance.
///
/// Coordinate convention:
///   - [relativeBearing]: 0 = straight ahead, negative = left, positive = right
///   - All distances in meters.
class ARPathPainter extends CustomPainter {
  final double relativeBearing; // -pi to pi
  final double distanceToNext; // meters
  final bool isFacingTarget;
  final bool isTurningAround; // |bearing| > 140°
  final Color primaryColor;

  /// Fraction from top where the floor horizon appears (camera tilt model).
  static const double _horizonFrac = 0.42;

  /// Fraction from top where "near floor" (at user's feet) appears.
  static const double _nearFrac = 0.95;

  /// Minimum distance for perspective (avoid div-by-zero).
  static const double _minDist = 0.25;

  /// Physical half-width of the navigation lane in meters.
  static const double _laneHalfM = 0.55;

  const ARPathPainter({
    required this.relativeBearing,
    required this.distanceToNext,
    required this.isFacingTarget,
    required this.isTurningAround,
    required this.primaryColor,
  });

  // ─── Perspective Projection ────────────────────────────────────────────────

  /// Projects a real-world floor point (dist meters ahead, lateralM meters sideways)
  /// into screen coordinates using 1/d perspective.
  Offset _project(double dist, double lateralM, Size size) {
    final d = max(dist, _minDist);
    final p = _minDist / d; // perspective factor: 1.0 when very close, → 0 when far

    // Vanishing point: offset slightly in bearing direction
    final vpX = size.width * 0.5 + sin(relativeBearing) * size.width * 0.28;
    final vpY = size.height * _horizonFrac;
    final nearY = size.height * _nearFrac;

    final screenY = vpY + (nearY - vpY) * p;
    // Horizontal: the vanishing point offset + lateral spread that narrows with distance
    final screenX = vpX + lateralM * size.width * 0.40 * p;

    return Offset(screenX, screenY);
  }

  // ─── Main Paint ────────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    if (isTurningAround) {
      _drawTurnAroundIndicator(canvas, size);
      return;
    }

    _drawPathLane(canvas, size);
    _drawProgressDots(canvas, size);
    _drawFloorChevron(canvas, size);
    _drawHorizonGlow(canvas, size);
  }

  // ─── Path Lane ─────────────────────────────────────────────────────────────

  void _drawPathLane(Canvas canvas, Size size) {
    const numSeg = 20;
    const maxD = 10.0;

    final leftEdge = <Offset>[];
    final rightEdge = <Offset>[];

    for (int i = 0; i <= numSeg; i++) {
      final t = i / numSeg;
      // Quadratic spacing: denser near camera (better perspective look)
      final d = _minDist + (maxD - _minDist) * (t * t);
      leftEdge.add(_project(d, -_laneHalfM, size));
      rightEdge.add(_project(d, _laneHalfM, size));
    }

    // ── Filled gradient polygon ──
    final lanePoly = Path()
      ..moveTo(leftEdge.first.dx, leftEdge.first.dy);
    for (final pt in leftEdge) { lanePoly.lineTo(pt.dx, pt.dy); }
    for (final pt in rightEdge.reversed) { lanePoly.lineTo(pt.dx, pt.dy); }
    lanePoly.close();

    final gradRect = Rect.fromLTWH(
      0,
      size.height * _horizonFrac,
      size.width,
      size.height * (_nearFrac - _horizonFrac),
    );
    canvas.drawPath(
      lanePoly,
      Paint()
        ..shader = LinearGradient(
          colors: [
            primaryColor.withValues(alpha: 0.30),
            primaryColor.withValues(alpha: 0.03),
          ],
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
        ).createShader(gradRect),
    );

    // ── Glowing edges ──
    final edgePaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.60)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    _polyline(canvas, leftEdge, edgePaint);
    _polyline(canvas, rightEdge, edgePaint);

    // ── Center dashed line ──
    _drawDashedCenterLine(canvas, size);
  }

  void _drawDashedCenterLine(Canvas canvas, Size size) {
    const dashDists = [0.5, 1.2, 2.0, 3.0, 4.5, 6.5];
    final dashPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.25)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < dashDists.length - 1; i += 2) {
      final a = _project(dashDists[i], 0, size);
      final b = _project(dashDists[i + 1], 0, size);
      canvas.drawLine(a, b, dashPaint);
    }
  }

  // ─── Progress Dots ────────────────────────────────────────────────────────

  void _drawProgressDots(Canvas canvas, Size size) {
    const distances = [1.0, 2.5, 4.5, 7.0];

    for (final d in distances) {
      if (d > distanceToNext + 1) continue; // don't show dots past target
      final pos = _project(d, 0, size);
      final radius = (7.0 * _minDist / max(d, _minDist)).clamp(2.0, 9.0);

      // Outer glow
      canvas.drawCircle(
        pos,
        radius * 2.5,
        Paint()
          ..color = primaryColor.withValues(alpha: 0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      // Solid dot
      canvas.drawCircle(
        pos,
        radius,
        Paint()..color = primaryColor.withValues(alpha: 0.85),
      );
    }
  }

  // ─── Floor Chevron Arrows (multiple, every 1 m) ──────────────────────────

  /// Draws chevron arrows on the floor at 1 m, 2 m, 3 m, and 4 m.
  /// Each subsequent arrow is smaller and more transparent, conveying depth.
  ///
  ///  ▶  1 m — 40 px, 100 % opacity
  ///  ▶  2 m — 30 px,  80 % opacity
  ///  ▶  3 m — 22 px,  55 % opacity
  ///  ▶  4 m — 16 px,  30 % opacity
  void _drawFloorChevron(Canvas canvas, Size size) {
    const arrowSpecs = [
      (dist: 1.0, halfWidth: 0.42, tailDist: 0.50, tailHalf: 0.22, alpha: 1.00),
      (dist: 2.0, halfWidth: 0.35, tailDist: 0.42, tailHalf: 0.18, alpha: 0.80),
      (dist: 3.0, halfWidth: 0.27, tailDist: 0.34, tailHalf: 0.14, alpha: 0.55),
      (dist: 4.0, halfWidth: 0.20, tailDist: 0.26, tailHalf: 0.10, alpha: 0.30),
    ];

    for (final spec in arrowSpecs) {
      if (spec.dist > distanceToNext + 0.5) break; // don't draw past the target

      final tip   = _project(spec.dist, 0, size);
      final lWing = _project(spec.dist + spec.tailDist, -spec.halfWidth, size);
      final rWing = _project(spec.dist + spec.tailDist,  spec.halfWidth, size);
      final lTail = _project(spec.dist + spec.tailDist + 0.25, -spec.tailHalf, size);
      final rTail = _project(spec.dist + spec.tailDist + 0.25,  spec.tailHalf, size);

      final chevPath = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(lWing.dx, lWing.dy)
        ..lineTo(lTail.dx, lTail.dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(rTail.dx, rTail.dy)
        ..lineTo(rWing.dx, rWing.dy)
        ..close();

      canvas.drawPath(
        chevPath,
        Paint()
          ..color = primaryColor.withValues(alpha: spec.alpha * 0.75)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        chevPath,
        Paint()
          ..color = primaryColor.withValues(alpha: spec.alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
  }


  // ─── Horizon Glow ─────────────────────────────────────────────────────────

  void _drawHorizonGlow(Canvas canvas, Size size) {
    // Subtle bloom at the vanishing point
    final vpX = size.width * 0.5 + sin(relativeBearing) * size.width * 0.28;
    final vpY = size.height * _horizonFrac;

    canvas.drawCircle(
      Offset(vpX, vpY),
      60,
      Paint()
        ..color = primaryColor.withValues(alpha: 0.06)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
    );
  }

  // ─── Turn-Around Indicator ────────────────────────────────────────────────

  void _drawTurnAroundIndicator(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.55;

    // Pulsing ring
    canvas.drawCircle(
      Offset(cx, cy),
      70,
      Paint()
        ..color = Colors.amberAccent.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      68,
      Paint()
        ..color = Colors.amberAccent.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // U-turn arrows (simplified)
    final arrowPaint = Paint()
      ..color = Colors.amberAccent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(cx - 20, cy + 20);
    path.lineTo(cx - 20, cy - 10);
    path.arcToPoint(Offset(cx + 20, cy - 10),
        radius: const Radius.circular(20), clockwise: true);
    path.lineTo(cx + 20, cy + 20);

    canvas.drawPath(path, arrowPaint);

    // Arrowhead
    canvas.drawLine(
        Offset(cx + 12, cy + 10), Offset(cx + 20, cy + 20), arrowPaint);
    canvas.drawLine(
        Offset(cx + 28, cy + 10), Offset(cx + 20, cy + 20), arrowPaint);
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  void _polyline(Canvas canvas, List<Offset> pts, Paint paint) {
    if (pts.length < 2) return;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) { path.lineTo(p.dx, p.dy); }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(ARPathPainter old) =>
      old.relativeBearing != relativeBearing ||
      old.distanceToNext != distanceToNext ||
      old.isFacingTarget != isFacingTarget ||
      old.isTurningAround != isTurningAround ||
      old.primaryColor != primaryColor;
}
