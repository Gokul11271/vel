import 'package:flutter/material.dart';
import '../models/pose.dart';
import '../models/node.dart';
import 'fps_counter.dart';

/// Developer debug overlay displayed on top of the AR camera feed.
/// Shows live telemetry: tracking state, nodes, distance, FPS, XYZ position.
///
/// Usage:
/// ```dart
/// DebugOverlay(
///   trackingState: TrackingState.good,
///   currentNode: n1,
///   nextNode: n2,
///   distanceToNext: 2.14,
///   userPose: pose,
///   fpsCounter: _fpsCounter,
/// )
/// ```
class DebugOverlay extends StatelessWidget {
  final TrackingState trackingState;
  final Node? currentNode;
  final Node? nextNode;
  final double distanceToNext;
  final Pose userPose;
  final FpsCounter fpsCounter;

  const DebugOverlay({
    super.key,
    required this.trackingState,
    required this.currentNode,
    required this.nextNode,
    required this.distanceToNext,
    required this.userPose,
    required this.fpsCounter,
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

    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 90, right: 12),
        child: Container(
          width: 185,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: DefaultTextStyle(
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: Colors.white70,
              height: 1.6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(Icons.bug_report_rounded, size: 12, color: Colors.white38),
                    const SizedBox(width: 4),
                    const Text('DEBUG', style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1.5)),
                    const Spacer(),
                    Text(
                      '${fps.toStringAsFixed(0)} FPS',
                      style: TextStyle(
                        color: fps >= 45 ? Colors.greenAccent : fps >= 25 ? Colors.amberAccent : Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const Divider(color: Colors.white12, height: 8),

                // Tracking
                Row(
                  children: [
                    Text('Tracking: ', style: const TextStyle(color: Colors.white54)),
                    Text(
                      trackingLabel,
                      style: TextStyle(color: trackingColor, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),

                // Nodes
                _row('Current', currentNode?.name ?? '--'),
                _row('Next', nextNode?.name ?? '--'),
                _row('Distance', '${distanceToNext.toStringAsFixed(2)} m'),

                const Divider(color: Colors.white12, height: 8),

                // Camera / position
                const Text('Camera:', style: TextStyle(color: Colors.white54)),
                _row('  X', pos.x.toStringAsFixed(2)),
                _row('  Y', pos.y.toStringAsFixed(2)),
                _row('  Z', pos.z.toStringAsFixed(2)),
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
