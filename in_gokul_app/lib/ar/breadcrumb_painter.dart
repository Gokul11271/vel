import 'dart:math';
import 'package:flutter/material.dart';
import '../models/breadcrumb.dart';
import '../models/node.dart';
import '../models/pose.dart';
import '../services/world_alignment_service.dart';
import '../theme/app_theme.dart';

/// Perspective floor renderer for sequential 3D breadcrumb markers.
///
/// Designed with a strict abstraction layer so that swapping screen projection
/// for native ARCore/ARKit world plane anchors (Phase 5) requires 0 changes
/// to Dijkstra or MapMatcher.
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
  static const double _maxRenderDistanceM = 14.0;

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
    // Phase 4: If tracking is completely lost, do NOT draw misleading floor markers
    if (trackingState == TrackingState.lost ||
        trackingState == TrackingState.notAvailable ||
        breadcrumbs.isEmpty) {
      return;
    }

    final camPos = cameraPose.position;
    final camYaw = cameraPose.yawRadians;

    // Camera rotation matrix (yaw around Y axis)
    final cosYaw = cos(-camYaw);
    final sinYaw = sin(-camYaw);

    final focalY = (size.height * 0.5) / tan((_fovYDegrees * pi / 180.0) * 0.5);
    final focalX = focalY; // Assuming square pixels

    final centerX = size.width * 0.5;
    final centerY = size.height * _horizonFrac;

    // Filter and project breadcrumbs ahead of active segment
    for (final crumb in breadcrumbs) {
      // Only draw current segment and upcoming segments
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
      final dy = worldPos.y - camPos.y; // Floor is below camera (dy negative)
      final dz = worldPos.z - camPos.z;

      // Rotate into camera coordinate system (Z is forward/depth, X is right, Y is up)
      final camX = cosYaw * dx - sinYaw * dz;
      final camZ = sinYaw * dx + cosYaw * dz;
      final camY = dy;

      // Breadcrumb must be in front of the camera (camZ < -0.3 in OpenGL camera convention, or depth > 0)
      final depth = -camZ; // Depth ahead
      if (depth < 0.4 || depth > _maxRenderDistanceM) continue;

      // Perspective projection
      final screenX = centerX + (camX * focalX) / depth;
      // Map vertical height with ground floor compensation
      final screenY = centerY - (camY * focalY) / depth;

      // Ensure point falls inside screen bounds with padding
      if (screenX < -50 || screenX > size.width + 50 || screenY < -50 || screenY > size.height + 50) {
        continue;
      }

      _drawBreadcrumbMarker(
        canvas: canvas,
        center: Offset(screenX, screenY),
        depth: depth,
        crumb: crumb,
        isCurrentSegment: crumb.segmentIndex == activeSegmentIndex,
      );
    }
  }

  void _drawBreadcrumbMarker({
    required Canvas canvas,
    required Offset center,
    required double depth,
    required Breadcrumb crumb,
    required bool isCurrentSegment,
  }) {
    // Perspective scaling factor (closer = larger)
    final scale = (1.0 / depth).clamp(0.18, 1.2);
    final radius = 16.0 * scale;

    // Depth-based opacity fading
    final opacity = (1.0 - (depth / _maxRenderDistanceM)).clamp(0.25, 0.95);

    final discColor = isCurrentSegment
        ? AppColors.lightBlue.withValues(alpha: opacity)
        : Colors.white.withValues(alpha: opacity * 0.7);

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

    // 3. Inner chevron marker
    final chevronPaint = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * scale
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

  @override
  bool shouldRepaint(covariant BreadcrumbPainter oldDelegate) {
    return oldDelegate.cameraPose.position != cameraPose.position ||
        oldDelegate.cameraPose.yawRadians != cameraPose.yawRadians ||
        oldDelegate.trackingState != trackingState ||
        oldDelegate.activeSegmentIndex != activeSegmentIndex ||
        oldDelegate.breadcrumbs != breadcrumbs;
  }
}
