import 'dart:async';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart';
import '../models/pose.dart';
import 'position_provider.dart';

class NativeArPositionProvider implements PositionProvider {
  static const MethodChannel _methodChannel = MethodChannel('com.example.indoornavigation/ar_session');
  static const EventChannel _poseEventChannel = EventChannel('com.example.indoornavigation/pose_stream');

  final StreamController<Pose> _poseController = StreamController<Pose>.broadcast();
  StreamSubscription? _platformSubscription;
  Pose _currentPose = Pose.identity();
  bool _isTracking = false;

  @override
  Stream<Pose> get poseStream => _poseController.stream;

  @override
  Pose get currentPose => _currentPose;

  bool get isTracking => _isTracking;

  @override
  Future<void> start() async {
    if (_isTracking) return;
    _isTracking = true;

    try {
      // Invoke native platform channel to start AR session
      await _methodChannel.invokeMethod('startArSession');
      
      _platformSubscription = _poseEventChannel.receiveBroadcastStream().listen(
        (data) {
          if (data is Map) {
            final x = (data['x'] as num?)?.toDouble() ?? 0.0;
            final y = (data['y'] as num?)?.toDouble() ?? 0.0;
            final z = (data['z'] as num?)?.toDouble() ?? 0.0;
            final qx = (data['qx'] as num?)?.toDouble() ?? 0.0;
            final qy = (data['qy'] as num?)?.toDouble() ?? 0.0;
            final qz = (data['qz'] as num?)?.toDouble() ?? 0.0;
            final qw = (data['qw'] as num?)?.toDouble() ?? 1.0;
            final stateIndex = data['state'] as int? ?? 0;
            final accuracy = (data['accuracy'] as num?)?.toDouble() ?? 0.05;

            final state = stateIndex >= 0 && stateIndex < TrackingState.values.length
                ? TrackingState.values[stateIndex]
                : TrackingState.good;

            final pose = Pose(
              position: Vector3(x, y, z),
              rotation: Quaternion(qx, qy, qz, qw),
              trackingState: state,
              accuracy: accuracy,
            );

            _updatePose(pose);
          }
        },
        onError: (err) {
          _updatePose(_currentPose.copyWith(trackingState: TrackingState.limited));
        },
      );
    } catch (e) {
      // Platform channel not found or running on web/unsupported platform:
      // Keep tracking active with fallback default pose
      _updatePose(_currentPose.copyWith(trackingState: TrackingState.good));
    }
  }

  /// Allows manual or fallback pose injection (e.g. from camera/gyro sensors)
  void updateManualPose(Pose pose) {
    _updatePose(pose);
  }

  void _updatePose(Pose pose) {
    _currentPose = pose;
    if (!_poseController.isClosed) {
      _poseController.add(pose);
    }
  }

  @override
  Future<void> stop() async {
    _isTracking = false;
    await _platformSubscription?.cancel();
    _platformSubscription = null;
    try {
      await _methodChannel.invokeMethod('stopArSession');
    } catch (_) {}
  }

  @override
  void dispose() {
    stop();
    _poseController.close();
  }
}
