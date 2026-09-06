import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import '../models/pose.dart';
import '../models/node.dart';
import 'fps_counter.dart';

/// Developer debug overlay displayed on top of the AR camera feed.
/// Shows live telemetry: tracking state, nodes, distance, segment progress, FPS, XYZ position.
class DebugOverlay extends StatelessWidget {
  final TrackingState trackingState;
  final Node? currentNode;
  final Node? nextNode;
  final double distanceToNext;
  final Pose userPose;
  final FpsCounter fpsCounter;
  final double segmentProgress;
  final int arrivalFrames;
  final Vector3? snappedPosition;

  const DebugOverlay({
    super.key,
    required this.trackingState,
    required this.currentNode,
    required this.nextNode,
    required this.distanceToNext,
    required this.userPose,
    required this.fpsCounter,
    this.segmentProgress = 0.0,
    this.arrivalFrames = 0,
    this.snappedPosition,
  });

  @override
  Widget build(BuildContext context) {
    fpsCounter.onFrame();
    final fps = fpsCounter.fps;
    final pos = userPose.position;
    final yaw = (userPose.yawDegrees + 360) % 360;

    final trackingColor = trackingState == TrackingState.good
        ? Colors.greenAccent
        : trackingState == TrackingState.limited
            ? Colors.amberAccent
            : Colors.redAccent;

    final trackingLabel = trackingState == TrackingState.good
        ? 'GOOD'
        : trackingState == TrackingState.limited
            ? 'LIMITED'
            : trackingState == TrackingState.lost
                ? 'LOST'
                : 'N/A';

    final progressPct = (segmentProgress * 100).clamp(0, 100);

    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 86, right: 10),
        child: Container(
          width: 195,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white24),
          ),
          child: DefaultTextStyle(
            style: const TextStyle(
              fontSize: 10.5,
              fontFamily: 'monospace',
              color: Colors.white70,
              height: 1.5,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(Icons.bug_report_rounded, size: 12, color: Colors.amberAccent),
                    const SizedBox(width: 4),
                    const Text('DIAGNOSTICS', style: TextStyle(color: Colors.amberAccent, fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text(
                      '${fps.toStringAsFixed(0)} FPS',
                      style: TextStyle(
                        color: fps >= 45 ? Colors.greenAccent : fps >= 25 ? Colors.amberAccent : Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const Divider(color: Colors.white24, height: 6),

                // Tracking
                Row(
                  children: [
                    const Text('Tracking: ', style: TextStyle(color: Colors.white54)),
                    Text(
                      trackingLabel,
                      style: TextStyle(color: trackingColor, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),

                // Nodes & Progression
                _row('Current', currentNode?.name ?? '--'),
                _row('Next', nextNode?.name ?? '--'),
                _row('Distance', '${distanceToNext.toStringAsFixed(2)} m'),
                _row('Progress t', '${progressPct.toStringAsFixed(0)}%'),
                _row('Arrival Lock', '$arrivalFrames/15'),

                const Divider(color: Colors.white24, height: 6),

                // Raw vs Snapped Coordinates
                const Text('User Pos (m):', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                _row('  Raw X/Z', '(${pos.x.toStringAsFixed(1)}, ${pos.z.toStringAsFixed(1)})'),
                if (snappedPosition != null)
                  _row('  Snap X/Z', '(${snappedPosition!.x.toStringAsFixed(1)}, ${snappedPosition!.z.toStringAsFixed(1)})'),
                _row('  Yaw', '${yaw.toStringAsFixed(1)}°'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      children: [
        Text('$label: ', style: const TextStyle(color: Colors.white54)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
