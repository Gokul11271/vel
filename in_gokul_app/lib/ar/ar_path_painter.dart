import 'dart:math';
import 'package:flutter/material.dart';

/// Paints a high-visibility perspective-projected AR floor navigation path.
///
/// Features:
///   1. Electric illuminated floor ribbon (lane) with neon edge rails.
///   2. Forward-pointing chevrons (▲) projected along the ground plane towards the destination.
///   3. Center guide track with glowing milestone markers.
///   4. Projected floor bullseye landing pad at the target waypoint.
class ARPathPainter extends CustomPainter {
  final double relativeBearing; // -pi to pi (0 = straight ahead)
  final double distanceToNext;  // meters
  final bool isFacingTarget;
  final bool isTurningAround;  // |bearing| > 130°
  final Color primaryColor;

  /// Horizon line position (fraction from top of screen).
  static const double _horizonFrac = 0.40;

  /// Near floor position at user's feet (fraction from top of screen).
  static const double _nearFrac = 0.94;

  /// Minimum distance in meters for perspective projection.
  static const double _minDist = 0.30;

  /// Physical half-width of the floor ribbon in meters.
  static const double _laneHalfM = 0.50;

  const ARPathPainter({
    required this.relativeBearing,
    required this.distanceToNext,
    required this.isFacingTarget,
    required this.isTurningAround,
    required this.primaryColor,
  });

  // ─── Perspective Projection ────────────────────────────────────────────────

  /// Projects a floor coordinate (distM ahead, lateralM sideways) to screen pixels.
  Offset _project(double distM, double lateralM, Size size) {
    final d = max(distM, _minDist);
    // Perspective factor: 1.0 near feet, smoothly converges to 0 at infinity
    final p = _minDist / d;

    // Vanishing point on horizon influenced by relative bearing
    final vpX = size.width * 0.5 + sin(relativeBearing) * size.width * 0.32;
    final vpY = size.height * _horizonFrac;
    final nearY = size.height * _nearFrac;

    // Floor Y position (screen height)
    final screenY = vpY + (nearY - vpY) * p;

    // Floor X position (screen width) with perspective foreshortening
    final screenX = vpX + lateralM * size.width * 0.45 * p;

    return Offset(screenX, screenY);
  }

  // ─── Main Paint ────────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    if (isTurningAround) {
      _drawTurnAroundIndicator(canvas, size);
      return;
    }

    _drawFloorRibbon(canvas, size);
    _drawCenterTrack(canvas, size);
    _drawForwardChevrons(canvas, size);
    _drawWaypointFloorTarget(canvas, size);
    _drawHorizonBloom(canvas, size);
  }

  // ─── 1. Illuminated Floor Ribbon (Ground Lane) ─────────────────────────────

  void _drawFloorRibbon(Canvas canvas, Size size) {
    const numSeg = 24;
    final maxD = max(distanceToNext + 1.5, 8.0).clamp(4.0, 14.0);

    final leftRail = <Offset>[];
    final rightRail = <Offset>[];

    for (int i = 0; i <= numSeg; i++) {
      final t = i / numSeg;
      // Quadratic distance distribution (denser near camera)
      final d = _minDist + (maxD - _minDist) * (t * t);
      leftRail.add(_project(d, -_laneHalfM, size));
      rightRail.add(_project(d, _laneHalfM, size));
    }

    // ── Ribbon Surface Fill ──
    final ribbonPath = Path()..moveTo(leftRail.first.dx, leftRail.first.dy);
    for (final pt in leftRail) {
      ribbonPath.lineTo(pt.dx, pt.dy);
    }
    for (final pt in rightRail.reversed) {
      ribbonPath.lineTo(pt.dx, pt.dy);
    }
    ribbonPath.close();

    final fillGradient = LinearGradient(
      colors: [
        primaryColor.withValues(alpha: 0.45),
        primaryColor.withValues(alpha: 0.18),
        primaryColor.withValues(alpha: 0.04),
      ],
      stops: const [0.0, 0.45, 1.0],
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
    );

    final bounds = Rect.fromLTWH(
      0,
      size.height * _horizonFrac,
      size.width,
      size.height * (_nearFrac - _horizonFrac),
    );

    canvas.drawPath(
      ribbonPath,
      Paint()..shader = fillGradient.createShader(bounds),
    );

    // ── Glowing Side Boundary Rails ──
    final outerRailGlow = Paint()
      ..color = primaryColor.withValues(alpha: 0.50)
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    final innerRailCore = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    _polyline(canvas, leftRail, outerRailGlow);
    _polyline(canvas, rightRail, outerRailGlow);
    _polyline(canvas, leftRail, innerRailCore);
    _polyline(canvas, rightRail, innerRailCore);
  }

  // ─── 2. Center Guide Track & Milestone Dots ────────────────────────────────

  void _drawCenterTrack(Canvas canvas, Size size) {
    const dashIntervals = [
      (0.5, 1.0),
      (1.4, 2.0),
      (2.5, 3.2),
      (3.8, 4.6),
      (5.4, 6.4),
      (7.2, 8.4),
    ];

    final dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.60)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final seg in dashIntervals) {
      if (seg.$1 > distanceToNext + 1.0) break;
      final p1 = _project(seg.$1, 0, size);
      final p2 = _project(min(seg.$2, distanceToNext), 0, size);
      canvas.drawLine(p1, p2, dashPaint);
    }
  }

  // ─── 3. Forward Chevrons (Pointing INTO the Corridor) ──────────────────────

  void _drawForwardChevrons(Canvas canvas, Size size) {
    // Chevron positions spaced along the floor ahead
    const chevronDistances = [0.8, 1.8, 3.0, 4.4, 6.0, 8.0];

    for (int i = 0; i < chevronDistances.length; i++) {
      final baseD = chevronDistances[i];
      if (baseD > distanceToNext) break; // Stop before destination

      // Perspective scaling: chevrons get smaller as distance increases
      final length = (0.50 * (_minDist / max(baseD, _minDist))).clamp(0.25, 0.55);
      final halfW  = (0.42 * (_minDist / max(baseD, _minDist))).clamp(0.20, 0.44);
      final alpha  = (1.0 - (i * 0.14)).clamp(0.25, 1.0);

      // FORWARD POINTING:
      // Tip is FURTHEST away (higher screen Y, larger dist)
      // Wings are CLOSER to user (lower screen Y, smaller dist)
      final tipD   = baseD + length;
      final wingD  = baseD;
      final notchD = baseD + length * 0.35;

      final tip   = _project(tipD, 0, size);
      final lWing = _project(wingD, -halfW, size);
      final rWing = _project(wingD, halfW, size);
      final notch = _project(notchD, 0, size);

      final chevPath = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(lWing.dx, lWing.dy)
        ..lineTo(notch.dx, notch.dy)
        ..lineTo(rWing.dx, rWing.dy)
        ..close();

      // Neon blur shadow
      canvas.drawPath(
        chevPath,
        Paint()
          ..color = primaryColor.withValues(alpha: alpha * 0.70)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );

      // Solid vibrant fill
      canvas.drawPath(
        chevPath,
        Paint()
          ..color = primaryColor.withValues(alpha: alpha * 0.90)
          ..style = PaintingStyle.fill,
      );

      // Bright white accent border
      canvas.drawPath(
        chevPath,
        Paint()
          ..color = Colors.white.withValues(alpha: alpha * 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  // ─── 4. Projected Floor Waypoint Landing Target ────────────────────────────

  void _drawWaypointFloorTarget(Canvas canvas, Size size) {
    if (distanceToNext > 12.0) return;

    final targetCenter = _project(distanceToNext, 0, size);
    final targetL = _project(distanceToNext, -0.65, size);
    final targetR = _project(distanceToNext, 0.65, size);
    final radiusX = (targetR.dx - targetL.dx).abs() * 0.5;
    final radiusY = max(radiusX * 0.35, 4.0); // Foreshortened floor ellipse

    final targetRect = Rect.fromCenter(
      center: targetCenter,
      width: radiusX * 2,
      height: radiusY * 2,
    );

    // Outer Target Pulse Ring
    canvas.drawOval(
      targetRect,
      Paint()
        ..color = primaryColor.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    canvas.drawOval(
      targetRect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Inner Bullseye Fill
    canvas.drawOval(
      Rect.fromCenter(
        center: targetCenter,
        width: radiusX * 0.8,
        height: radiusY * 0.8,
      ),
      Paint()
        ..color = primaryColor.withValues(alpha: 0.55)
        ..style = PaintingStyle.fill,
    );

    // Center Landing Pin
    canvas.drawCircle(
      targetCenter,
      (4.0 * _minDist / max(distanceToNext, _minDist)).clamp(2.5, 6.0),
      Paint()..color = Colors.white,
    );
  }

  // ─── 5. Horizon Bloom Glow ────────────────────────────────────────────────

  void _drawHorizonBloom(Canvas canvas, Size size) {
    final vpX = size.width * 0.5 + sin(relativeBearing) * size.width * 0.32;
    final vpY = size.height * _horizonFrac;

    canvas.drawCircle(
      Offset(vpX, vpY),
      80,
      Paint()
        ..color = primaryColor.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 35),
    );
  }

  // ─── 6. Turn-Around Indicator ─────────────────────────────────────────────

  void _drawTurnAroundIndicator(Canvas canvas, Size size) {
    final cx = size.width * 0.5;
    final cy = size.height * 0.52;

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
        ..color = Colors.amberAccent.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    final arrowPaint = Paint()
      ..color = Colors.amberAccent
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(cx - 22, cy + 22)
      ..lineTo(cx - 22, cy - 10)
      ..arcToPoint(
        Offset(cx + 22, cy - 10),
        radius: const Radius.circular(22),
        clockwise: true,
      )
      ..lineTo(cx + 22, cy + 22);

    canvas.drawPath(path, arrowPaint);

    canvas.drawLine(
      Offset(cx + 12, cy + 12),
      Offset(cx + 22, cy + 22),
      arrowPaint,
    );
    canvas.drawLine(
      Offset(cx + 32, cy + 12),
      Offset(cx + 22, cy + 22),
      arrowPaint,
    );
  }

  void _polyline(Canvas canvas, List<Offset> pts, Paint paint) {
    if (pts.length < 2) return;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(ARPathPainter oldDelegate) =>
      oldDelegate.relativeBearing != relativeBearing ||
      oldDelegate.distanceToNext != distanceToNext ||
      oldDelegate.isFacingTarget != isFacingTarget ||
      oldDelegate.isTurningAround != isTurningAround ||
      oldDelegate.primaryColor != primaryColor;
}
