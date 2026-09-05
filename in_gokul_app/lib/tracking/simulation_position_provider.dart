import 'dart:async';
import 'dart:math';
import 'package:vector_math/vector_math_64.dart';
import '../models/pose.dart';
import 'position_provider.dart';

class SimulationPositionProvider implements PositionProvider {
  final StreamController<Pose> _poseController = StreamController<Pose>.broadcast();
  Pose _currentPose = Pose.identity();
  Timer? _playbackTimer;
  bool _isRunning = false;

  @override
  Stream<Pose> get poseStream => _poseController.stream;

  @override
  Pose get currentPose => _currentPose;

  bool get isRunning => _isRunning;

  @override
  Future<void> start() async {
    _isRunning = true;
    _emitPose(_currentPose);
  }

  /// Sets position and calculates yaw towards a target
  void setPosition({
    required double x,
    required double y,
    required double z,
    double? yawRadians,
    TrackingState trackingState = TrackingState.good,
  }) {
    final yaw = yawRadians ?? _currentPose.yawRadians;
    final pose = Pose.fromValues(
      x: x,
      y: y,
      z: z,
      yawRadians: yaw,
      trackingState: trackingState,
    );
    _emitPose(pose);
  }

  /// Step towards a world target position by [stepMeters]
  void stepTowards(Vector3 targetPos, {double stepMeters = 0.5}) {
    final currentPos = _currentPose.position;
    final delta = targetPos - currentPos;
    final dist = delta.length;

    if (dist <= stepMeters) {
      final yaw = delta.length2 > 0 ? atan2(delta.x, -delta.z) : _currentPose.yawRadians;
      setPosition(x: targetPos.x, y: targetPos.y, z: targetPos.z, yawRadians: yaw);
    } else {
      final ratio = stepMeters / dist;
      final newPos = currentPos + (delta * ratio);
      final yaw = atan2(delta.x, -delta.z);
      setPosition(x: newPos.x, y: newPos.y, z: newPos.z, yawRadians: yaw);
    }
  }

  void setTrackingState(TrackingState state) {
    _emitPose(_currentPose.copyWith(trackingState: state));
  }

  void _emitPose(Pose pose) {
    _currentPose = pose;
    if (!_poseController.isClosed) {
      _poseController.add(pose);
    }
  }

  @override
  Future<void> stop() async {
    _isRunning = false;
    _playbackTimer?.cancel();
    _playbackTimer = null;
  }

  @override
  void dispose() {
    stop();
    _poseController.close();
  }
}
