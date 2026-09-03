import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:vector_math/vector_math_64.dart';
import '../models/pose.dart';
import 'position_provider.dart';

class NativeArPositionProvider implements PositionProvider {
  static const MethodChannel _methodChannel =
      MethodChannel('com.example.indoornavigation/ar_session');
  static const EventChannel _poseEventChannel =
      EventChannel('com.example.indoornavigation/pose_stream');

  final StreamController<Pose> _poseController =
      StreamController<Pose>.broadcast();
  StreamSubscription? _platformSubscription;
  StreamSubscription? _compassSubscription;
  StreamSubscription? _accelSubscription;

  Pose _currentPose = Pose.identity();
  Vector3 _currentPosition = Vector3.zero();
  double _currentHeadingRadians = 0.0;
  bool _isTracking = false;
  DateTime _lastStepTime = DateTime.now();

  // --- Low-pass filter state for accelerometer ---
  double _lpfX = 0.0, _lpfY = 0.0, _lpfZ = 0.0;
  static const double _lpfAlpha = 0.12; // smoothing factor (0 = max smooth)

  // --- Pitch estimation from accelerometer ---
  double _pitchRadians = 0.0;

  // --- Step detection hysteresis ---
  bool _stepPeak = false;
  static const double _stepThresholdHigh = 1.20;
  static const double _stepThresholdLow = 0.60;
  static const int _stepMinIntervalMs = 280;

  int _totalSteps = 0;
  int get totalSteps => _totalSteps;

  @override
  Stream<Pose> get poseStream => _poseController.stream;

  @override
  Pose get currentPose => _currentPose;

  double get currentHeadingRadians => _currentHeadingRadians;
  double get currentHeadingDegrees => _currentHeadingRadians * (180.0 / pi);
  double get pitchDegrees => _pitchRadians * (180.0 / pi);
  bool get isTracking => _isTracking;

  @override
  Future<void> start() async {
    if (_isTracking) return;
    _isTracking = true;

    // 1. Real-time device compass / magnetometer
    _initCompassTracking();

    // 2. Accelerometer: step detection + pitch estimation
    _initStepDetection();

    // 3. Optional: native ARCore/ARKit pose stream (if platform plugin active)
    _initNativeARSession();

    _emitCurrentPose();
  }

  void _initCompassTracking() {
    try {
      if (FlutterCompass.events != null) {
        _compassSubscription = FlutterCompass.events!.listen(
          (CompassEvent event) {
            final headingDeg = event.heading;
            if (headingDeg != null && !_poseController.isClosed) {
              _currentHeadingRadians = headingDeg * (pi / 180.0);
              _updateRotationFromSensors();
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
          // --- Low-pass filter (gravity component) ---
          _lpfX = _lpfAlpha * event.x + (1 - _lpfAlpha) * _lpfX;
          _lpfY = _lpfAlpha * event.y + (1 - _lpfAlpha) * _lpfY;
          _lpfZ = _lpfAlpha * event.z + (1 - _lpfAlpha) * _lpfZ;

          // --- Pitch estimation from gravity vector ---
          // pitch = atan2(-gx, sqrt(gy^2 + gz^2))
          final gMag = sqrt(_lpfX * _lpfX + _lpfY * _lpfY + _lpfZ * _lpfZ);
          if (gMag > 0.1) {
            _pitchRadians = asin((_lpfY / gMag).clamp(-1.0, 1.0));
          }

          // --- High-pass (dynamic) component = raw - gravity ---
          final dynX = event.x - _lpfX;
          final dynY = event.y - _lpfY;
          final dynZ = event.z - _lpfZ;
          final dynMag = sqrt(dynX * dynX + dynY * dynY + dynZ * dynZ);

          // --- Hysteresis peak detector ---
          final now = DateTime.now();
          if (!_stepPeak &&
              dynMag > _stepThresholdHigh &&
              now.difference(_lastStepTime).inMilliseconds > _stepMinIntervalMs) {
            _stepPeak = true;
            _lastStepTime = now;
            _totalSteps++;
            stepForward(0.65); // 65 cm stride length
          } else if (_stepPeak && dynMag < _stepThresholdLow) {
            _stepPeak = false; // reset for next step
          }
        },
        onError: (_) {},
      );
    } catch (_) {}
  }

  void _initNativeARSession() {
    try {
      _methodChannel.invokeMethod('startArSession');
      _platformSubscription =
          _poseEventChannel.receiveBroadcastStream().listen(
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

            // Native AR session takes full priority over sensor fusion
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

  /// Builds full 6DOF rotation quaternion from compass heading + accelerometer pitch.
  /// Q = Ry(yaw) * Rx(pitch)
  void _updateRotationFromSensors() {
    final qYaw = Quaternion.axisAngle(Vector3(0, 1, 0), _currentHeadingRadians);
    final qPitch = Quaternion.axisAngle(Vector3(1, 0, 0), _pitchRadians);
    final combined = qYaw * qPitch;
    combined.normalize();

    _currentPose = Pose(
      position: _currentPosition.clone(),
      rotation: combined,
      trackingState: TrackingState.good,
      accuracy: 0.05,
    );
    _emitCurrentPose();
  }

  /// Steps forward by [meters] in the direction of the current compass heading
  void stepForward(double meters) {
    final dx = sin(_currentHeadingRadians) * meters;
    final dz = -cos(_currentHeadingRadians) * meters;
    _currentPosition.x += dx;
    _currentPosition.z += dz;
    _updateRotationFromSensors();
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
    _totalSteps++;
    _updateRotationFromSensors();
  }

  /// Sets position directly (e.g. from GPS or node anchor)
  void setPosition(Vector3 pos) {
    _currentPosition = pos.clone();
    _updateRotationFromSensors();
  }

  void resetPosition() {
    _currentPosition = Vector3.zero();
    _updateRotationFromSensors();
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
