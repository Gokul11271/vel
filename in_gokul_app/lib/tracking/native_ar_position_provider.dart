import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:vector_math/vector_math_64.dart';
import '../models/pose.dart';
import 'position_provider.dart';

class NativeArPositionProvider implements PositionProvider {
  static const MethodChannel _methodChannel = MethodChannel('com.example.indoornavigation/ar_session');
  static const EventChannel _poseEventChannel = EventChannel('com.example.indoornavigation/pose_stream');

  final StreamController<Pose> _poseController = StreamController<Pose>.broadcast();
  StreamSubscription? _platformSubscription;
  StreamSubscription? _compassSubscription;
  StreamSubscription? _accelSubscription;

  Pose _currentPose = Pose.identity();
  Vector3 _currentPosition = Vector3.zero();
  double _currentHeadingRadians = 0.0;
  bool _isTracking = false;
  DateTime _lastStepTime = DateTime.now();

  @override
  Stream<Pose> get poseStream => _poseController.stream;

  @override
  Pose get currentPose => _currentPose;

  double get currentHeadingRadians => _currentHeadingRadians;
  double get currentHeadingDegrees => _currentHeadingRadians * (180.0 / pi);
  bool get isTracking => _isTracking;

  @override
  Future<void> start() async {
    if (_isTracking) return;
    _isTracking = true;

    // 1. Listen to Real-Time Device Compass / Magnetometer
    _initCompassTracking();

    // 2. Listen to Accelerometer for Step Detection / Inertial Motion
    _initStepDetection();

    // 3. Optional Native AR session (if available)
    _initNativeARSession();

    _emitCurrentPose();
  }

  void _initCompassTracking() {
    try {
      if (FlutterCompass.events != null) {
        _compassSubscription = FlutterCompass.events!.listen(
          (CompassEvent event) {
            final headingDeg = event.heading;
            if (headingDeg != null) {
              _currentHeadingRadians = headingDeg * (pi / 180.0);
              _updateRotationFromHeading();
            }
          },
          onError: (_) {},
        );
      }
    } catch (_) {}
  }

  void _initStepDetection() {
    try {
      _accelSubscription = userAccelerometerEventStream().listen(
        (UserAccelerometerEvent event) {
          // Detect step peak in acceleration
          final mag = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
          final now = DateTime.now();
          if (mag > 2.2 && now.difference(_lastStepTime).inMilliseconds > 400) {
            _lastStepTime = now;
            // Advance position by 0.65m along current heading
            stepForward(0.65);
          }
        },
        onError: (_) {},
      );
    } catch (_) {}
  }

  void _initNativeARSession() {
    try {
      _methodChannel.invokeMethod('startArSession');
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

            _currentPosition = Vector3(x, y, z);
            final rot = Quaternion(qx, qy, qz, qw);
            _currentPose = Pose(
              position: _currentPosition.clone(),
              rotation: rot,
              trackingState: state,
              accuracy: accuracy,
            );
            _poseController.add(_currentPose);
          }
        },
        onError: (_) {},
      );
    } catch (_) {}
  }

  void _updateRotationFromHeading() {
    final rot = Quaternion.axisAngle(Vector3(0, 1, 0), _currentHeadingRadians);
    _currentPose = Pose(
      position: _currentPosition.clone(),
      rotation: rot,
      trackingState: TrackingState.good,
      accuracy: 0.05,
    );
    _emitCurrentPose();
  }

  /// Steps forward by [meters] in the direction of the current compass heading
  void stepForward(double meters) {
    // In camera coordinates, heading 0 is north: dx = sin(h), dz = -cos(h)
    final dx = sin(_currentHeadingRadians) * meters;
    final dz = -cos(_currentHeadingRadians) * meters;
    _currentPosition.x += dx;
    _currentPosition.z += dz;
    _updateRotationFromHeading();
  }

  /// Steps towards a specified world target coordinate by [stepMeters]
  void stepTowards(Vector3 targetPos, {double stepMeters = 0.8}) {
    final delta = targetPos - _currentPosition;
    final dist = delta.length;
    if (dist <= stepMeters) {
      _currentPosition = targetPos.clone();
    } else {
      final step = delta * (stepMeters / dist);
      _currentPosition += step;
    }
    _updateRotationFromHeading();
  }

  /// Sets position directly (e.g. from GPS or node anchor)
  void setPosition(Vector3 pos) {
    _currentPosition = pos.clone();
    _updateRotationFromHeading();
  }

  void resetPosition() {
    _currentPosition = Vector3.zero();
    _updateRotationFromHeading();
  }

  void _emitCurrentPose() {
    if (!_poseController.isClosed) {
      _poseController.add(_currentPose);
    }
  }

  @override
  Future<void> stop() async {
    _isTracking = false;
    await _platformSubscription?.cancel();
    await _compassSubscription?.cancel();
    await _accelSubscription?.cancel();
    _platformSubscription = null;
    _compassSubscription = null;
    _accelSubscription = null;
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
