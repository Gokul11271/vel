import 'dart:math';
import 'package:flutter/material.dart';
import '../models/breadcrumb.dart';
import '../models/node.dart';
import '../models/pose.dart';
import '../services/world_alignment_service.dart';
import '../theme/app_theme.dart';

/// Perspective floor renderer for sequential 3D breadcrumb markers and floor highway.
///
/// Features:
/// - 3D floor perspective projection (ground height and horizon compensation)
/// - Continuous glowing floor highway ribbon connecting sequential breadcrumbs
/// - Depth-scaled floor chevrons oriented along corridor tangents
/// - Terminal destination target beacon
class BreadcrumbPainter extends CustomPainter {
  final List<Breadcrumb> breadcrumbs;
  final WorldAlignmentService alignmentService;
  final Pose cameraPose;
  final TrackingState trackingState;
  final int activeSegmentIndex;
  final Color primaryColor;

  /// Vertical field of view in degrees for perspective camera matrix estimation.
  static const double _fovYDegrees = 65.0;

  /// Horizon line fraction from top of viewport.
  static const double _horizonFrac = 0.42;

  /// Maximum distance to render breadcrumbs (metres).
  static const double _maxRenderDistanceM = 16.0;

  const BreadcrumbPainter({
    required this.breadcrumbs,
    required this.alignmentService,
    required this.cameraPose,
    required this.trackingState,
    required this.activeSegmentIndex,
    this.primaryColor = AppColors.primaryBlue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Suppress drawing when tracking is lost or unavailable
    if (trackingState == TrackingState.lost ||
        trackingState == TrackingState.notAvailable ||
        breadcrumbs.isEmpty) {
      return;
    }

    final camPos = cameraPose.position;
    final camYaw = cameraPose.yawRadians;

    final cosYaw = cos(-camYaw);
    final sinYaw = sin(-camYaw);

    final focalY = (size.height * 0.5) / tan((_fovYDegrees * pi / 180.0) * 0.5);
    final focalX = focalY;

    final centerX = size.width * 0.5;
    final centerY = size.height * _horizonFrac;

    // Projected point cache for consecutive runway connection
    final projectedPoints = <_ProjectedBreadcrumb>[];

    for (int i = 0; i < breadcrumbs.length; i++) {
      final crumb = breadcrumbs[i];
      if (crumb.segmentIndex < activeSegmentIndex) continue;

      // Transform JSON coordinate to 3D World Space
      final worldPos = alignmentService.transformJsonToWorld(
        Node(
          id: -1,
          name: '',
          x: crumb.jsonPosition.x,
          y: crumb.jsonPosition.y,
          z: crumb.jsonPosition.z,
        ),
      );

      // Delta from camera in world space
      final dx = worldPos.x - camPos.x;
      final dy = worldPos.y - camPos.y;
      final dz = worldPos.z - camPos.z;

      // Rotate into camera coordinate system
      final camX = cosYaw * dx - sinYaw * dz;
      final camZ = sinYaw * dx + cosYaw * dz;
      final camY = dy;

      final depth = -camZ;
      if (depth < 0.3 || depth > _maxRenderDistanceM) continue;

      // Perspective projection
      final screenX = centerX + (camX * focalX) / depth;
      final rawScreenY = centerY - (camY * focalY) / depth;

      // Horizon pitch clipping: clamp so floor elements stay locked to floor level
      final double maxHorizonY = size.height * 0.35;
      final double screenY = rawScreenY.clamp(maxHorizonY, size.height * 1.05);

      final isLast = (i == breadcrumbs.length - 1);

      projectedPoints.add(
        _ProjectedBreadcrumb(
          offset: Offset(screenX, screenY),
          depth: depth,
          crumb: crumb,
          isDestination: isLast,
        ),
      );
    }

    // 1. Draw glowing floor highway / runway path connecting consecutive points
    if (projectedPoints.length >= 2) {
      _drawFloorHighway(canvas, projectedPoints);
    }

    // 2. Draw 3D floor markers & chevrons (from farthest to nearest for correct z-sorting)
    projectedPoints.sort((a, b) => b.depth.compareTo(a.depth));

    for (final pt in projectedPoints) {
      if (pt.isDestination) {
        _drawDestinationBeacon(canvas, pt.offset, pt.depth);
      } else {
        _drawBreadcrumbMarker(
          canvas: canvas,
          center: pt.offset,
          depth: pt.depth,
          crumb: pt.crumb,
          isCurrentSegment: pt.crumb.segmentIndex == activeSegmentIndex,
        );
      }
    }
  }

  /// Draws a continuous illuminated highway ribbon on the floor
  void _drawFloorHighway(Canvas canvas, List<_ProjectedBreadcrumb> points) {
    // Sort in path order (by distance along path)
    final sorted = List<_ProjectedBreadcrumb>.from(points)
      ..sort((a, b) => a.crumb.distanceAlongPath.compareTo(b.crumb.distanceAlongPath));

    final path = Path();
    path.moveTo(sorted.first.offset.dx, sorted.first.offset.dy);
    for (int i = 1; i < sorted.length; i++) {
      path.lineTo(sorted[i].offset.dx, sorted[i].offset.dy);
    }

    // Outer glow ribbon
    final glowPaint = Paint()
      ..color = AppColors.lightBlue.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, glowPaint);

    // Inner bright neon ribbon
    final ribbonPaint = Paint()
      ..color = AppColors.primaryBlue.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, ribbonPaint);

    // Center dash pulse
    final centerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, centerPaint);
  }

  void _drawBreadcrumbMarker({
    required Canvas canvas,
    required Offset center,
    required double depth,
    required Breadcrumb crumb,
    required bool isCurrentSegment,
  }) {
    final scale = (1.0 / depth).clamp(0.18, 1.2);
    final radius = 16.0 * scale;
    final opacity = (1.0 - (depth / _maxRenderDistanceM)).clamp(0.25, 0.95);

    final discColor = isCurrentSegment
        ? AppColors.lightBlue.withValues(alpha: opacity)
        : Colors.white.withValues(alpha: opacity * 0.75);

    final haloColor = AppColors.primaryBlue.withValues(alpha: opacity * 0.35);

    // 1. Soft ground halo glow
    final haloPaint = Paint()
      ..color = haloColor
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: center, width: radius * 2.8, height: radius * 1.4),
      haloPaint,
    );

    // 2. Solid floor disc
    final discPaint = Paint()
      ..color = discColor
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: center, width: radius * 1.8, height: radius * 0.9),
      discPaint,
    );

    // 3. Inner directional chevron
    final chevronPaint = Paint()
      ..color = isCurrentSegment ? Colors.white : AppColors.navyDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4 * scale
      ..strokeCap = StrokeCap.round;

    final chevronPath = Path();
    final halfW = radius * 0.55;
    final tipY = center.dy - radius * 0.25;
    final baseY = center.dy + radius * 0.25;

    chevronPath.moveTo(center.dx - halfW, baseY);
    chevronPath.lineTo(center.dx, tipY);
    chevronPath.lineTo(center.dx + halfW, baseY);

    canvas.drawPath(chevronPath, chevronPaint);
  }

  void _drawDestinationBeacon(Canvas canvas, Offset center, double depth) {
    final scale = (1.0 / depth).clamp(0.25, 1.5);
    final radius = 28.0 * scale;
    final opacity = (1.0 - (depth / _maxRenderDistanceM)).clamp(0.4, 1.0);

    // Outer beacon pulse ring
    final ringPaint = Paint()
      ..color = AppColors.accentBlue.withValues(alpha: opacity * 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0 * scale;
    canvas.drawOval(
      Rect.fromCenter(center: center, width: radius * 3.2, height: radius * 1.6),
      ringPaint,
    );

    // Core target disc
    final corePaint = Paint()
      ..color = AppColors.lightBlue.withValues(alpha: opacity * 0.9)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: center, width: radius * 1.8, height: radius * 0.9),
      corePaint,
    );

    // Destination flag icon pin
    final pinPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(center.dx, center.dy - radius * 0.6), 4.0 * scale, pinPaint);
  }

  @override
  bool shouldRepaint(covariant BreadcrumbPainter oldDelegate) {
    return oldDelegate.cameraPose.position != cameraPose.position ||
        oldDelegate.cameraPose.yawRadians != cameraPose.yawRadians ||
        oldDelegate.trackingState != trackingState ||
        oldDelegate.activeSegmentIndex != activeSegmentIndex ||
        oldDelegate.breadcrumbs != breadcrumbs;
  }
}

class _ProjectedBreadcrumb {
  final Offset offset;
  final double depth;
  final Breadcrumb crumb;
  final bool isDestination;

  _ProjectedBreadcrumb({
    required this.offset,
    required this.depth,
    required this.crumb,
    required this.isDestination,
  });
}

