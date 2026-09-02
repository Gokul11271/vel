import 'dart:math';
import 'package:vector_math/vector_math_64.dart';

enum TrackingState {
  good,
  limited,
  lost,
  notAvailable,
}

extension TrackingStateExtension on TrackingState {
  String get label {
    switch (this) {
      case TrackingState.good:
        return 'TRACKING: GOOD';
      case TrackingState.limited:
        return 'TRACKING: LIMITED';
      case TrackingState.lost:
        return 'TRACKING: LOST';
      case TrackingState.notAvailable:
        return 'TRACKING: UNAVAILABLE';
    }
  }
}

class Pose {
  final Vector3 position;
  final Quaternion rotation;
  final TrackingState trackingState;
  final DateTime timestamp;
  final double accuracy; // In meters

  Pose({
    required this.position,
    required this.rotation,
    this.trackingState = TrackingState.good,
    DateTime? timestamp,
    this.accuracy = 0.05,
  }) : timestamp = timestamp ?? DateTime.now();

  factory Pose.identity({TrackingState trackingState = TrackingState.good}) {
    return Pose(
      position: Vector3.zero(),
      rotation: Quaternion.identity(),
      trackingState: trackingState,
    );
  }

  factory Pose.fromValues({
    required double x,
    required double y,
    required double z,
    double yawRadians = 0.0,
    TrackingState trackingState = TrackingState.good,
    double accuracy = 0.05,
  }) {
    final rotation = Quaternion.axisAngle(Vector3(0, 1, 0), yawRadians);
    return Pose(
      position: Vector3(x, y, z),
      rotation: rotation,
      trackingState: trackingState,
      accuracy: accuracy,
    );
  }

  /// Calculates yaw angle (rotation around Y axis) in radians
  double get yawRadians {
    final v = Vector3(0, 0, -1);
    final rotated = rotation.rotated(v);
    return atan2(rotated.x, -rotated.z);
  }

  double get yawDegrees => yawRadians * (180.0 / pi);

  double distanceTo(Pose other) {
    return position.distanceTo(other.position);
  }

  Pose copyWith({
    Vector3? position,
    Quaternion? rotation,
    TrackingState? trackingState,
    DateTime? timestamp,
    double? accuracy,
  }) {
    return Pose(
      position: position ?? this.position.clone(),
      rotation: rotation ?? this.rotation.clone(),
      trackingState: trackingState ?? this.trackingState,
      timestamp: timestamp ?? this.timestamp,
      accuracy: accuracy ?? this.accuracy,
    );
  }

  @override
  String toString() {
    return 'Pose(x: ${position.x.toStringAsFixed(2)}, y: ${position.y.toStringAsFixed(2)}, z: ${position.z.toStringAsFixed(2)}, yaw: ${yawDegrees.toStringAsFixed(1)}°, state: ${trackingState.name})';
  }
}
