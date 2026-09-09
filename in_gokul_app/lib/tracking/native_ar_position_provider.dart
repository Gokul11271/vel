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
  StreamSubscription? _gyroSubscription;

  final StreamController<bool> _anomalyController =
      StreamController<bool>.broadcast();
  Stream<bool> get onMagneticAnomaly => _anomalyController.stream;
  int _anomalyTicks = 0;

  Pose _currentPose = Pose.identity();
  Vector3 _currentPosition = Vector3.zero();
  double _currentHeadingRadians = 0.0;
  bool _isTracking = false;
  DateTime _lastStepTime = DateTime.now();
  DateTime _lastGyroTime = DateTime.now();

  // --- Pitch & dynamic acceleration state ---
  double _pitchRadians = 0.0;
  double _filteredMag = 0.0;

  // --- Multi-sensor Step detection hysteresis ---
  bool _stepPeak = false;
  static const double _stepThresholdHigh = 0.15; // Low threshold for maximum physical walking sensitivity (m/s²)
  static const double _stepThresholdLow = 0.06;  // Hysteresis reset (m/s²)
  static const int _stepMinIntervalMs = 250;     // Min time between steps (~4 steps/sec max)
  static const double defaultStepLengthM = 0.70; // 70 cm per adult stride

  StreamSubscription? _userAccelSubscription;
  StreamSubscription? _rawAccelSubscription;

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

    // 1. Real-time compass with magnetic noise rejection
    _initCompassTracking();

    // 2. Gyroscope assistance for smooth relative turning
    _initGyroscopeTracking();

    // 3. Multi-sensor step detection + pitch estimation
    _initStepDetection();

    _emitCurrentPose();
  }

  double _normalizeAngle(double a) {
    while (a > pi) {
      a -= 2 * pi;
    }
    while (a < -pi) {
      a += 2 * pi;
    }
    return a;
  }

  void _initCompassTracking() {
    try {
      if (FlutterCompass.events != null) {
        _compassSubscription = FlutterCompass.events!.listen(
          (CompassEvent event) {
            final headingDeg = event.heading;
            if (headingDeg != null && !_poseController.isClosed) {
              final rawHeadingRad = headingDeg * (pi / 180.0);
              // Angular difference between incoming compass reading and filtered heading
              final diff = _normalizeAngle(rawHeadingRad - _currentHeadingRadians);

              // Detect magnetic spikes (> 35 degrees / ~0.61 rad)
              if (diff.abs() > 0.61) {
                _anomalyTicks++;
                if (_anomalyTicks >= 3 && !_anomalyController.isClosed) {
                  _anomalyTicks = 0;
                  _anomalyController.add(true);
                }
              } else {
                if (_anomalyTicks > 0) _anomalyTicks--;
              }

              // Slew rate limiter: reject sudden magnetic fluctuations indoors
              final maxStep = 0.12; // ~7 degrees per compass frame max
              final clampedDiff = diff.clamp(-maxStep, maxStep);

              _currentHeadingRadians = _normalizeAngle(_currentHeadingRadians + clampedDiff);
              _updateRotationFromSensors();
            }
          },
          onError: (_) {},
        );
      }
    } catch (_) {}
  }

  void _initGyroscopeTracking() {
    try {
      _lastGyroTime = DateTime.now();
      _gyroSubscription = gyroscopeEventStream().listen(
        (GyroscopeEvent event) {
          final now = DateTime.now();
          final dt = now.difference(_lastGyroTime).inMicroseconds / 1000000.0;
          _lastGyroTime = now;

          if (dt > 0.001 && dt < 0.2) {
            final gyroDelta = -event.z * dt;
            if (gyroDelta.abs() > 0.002) {
              _currentHeadingRadians = _normalizeAngle(_currentHeadingRadians + gyroDelta);
              _updateRotationFromSensors();
            }
          }
        },
        onError: (_) {},
      );
    } catch (_) {}
  }

  void _registerStep(String source) {
    _totalSteps++;
    stepForward(defaultStepLengthM);
  }

  void _processAccelMagnitude(double mag) {
    _filteredMag = 0.45 * mag + 0.55 * _filteredMag;
    final now = DateTime.now();
    if (!_stepPeak &&
        _filteredMag > _stepThresholdHigh &&
        now.difference(_lastStepTime).inMilliseconds > _stepMinIntervalMs) {
      _stepPeak = true;
      _lastStepTime = now;
      _registerStep('accelerometer');
    } else if (_stepPeak && _filteredMag < _stepThresholdLow) {
      _stepPeak = false;
    }
  }

  void _initStepDetection() {

    try {
      // 2. User Linear Acceleration (Gravity-removed vector)
      _userAccelSubscription = userAccelerometerEventStream().listen(
        (UserAccelerometerEvent event) {
          final userMag = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
          _processAccelMagnitude(userMag);
        },
        onError: (_) {},
      );
    } catch (_) {}

    try {
      // 3. Raw Accelerometer (Gravity Vector & Dynamic Peak Detection)
      _rawAccelSubscription = accelerometerEventStream().listen(
        (AccelerometerEvent event) {
          final rawMag = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

          // Dynamic deviation from gravity (~9.80665 m/s²)
          final dynamicMag = (rawMag - 9.80665).abs();
          _processAccelMagnitude(dynamicMag);

          // Pitch estimation
          if (rawMag > 1.0) {
            _pitchRadians = asin((event.y / rawMag).clamp(-1.0, 1.0));
          }
        },
        onError: (_) {},
      );
    } catch (_) {}
  }

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

  /// Sets heading directly (e.g. for manual alignment or compass recalibration)
  void setHeadingRadians(double rad) {
    _currentHeadingRadians = _normalizeAngle(rad);
    _updateRotationFromSensors();
  }

  /// Steps forward in direction of current compass heading
  void stepForward(double meters) {
    final dx = sin(_currentHeadingRadians) * meters;
    final dz = -cos(_currentHeadingRadians) * meters;
    _currentPosition.x += dx;
    _currentPosition.z += dz;
    _updateRotationFromSensors();
  }

  /// Manual step for testing, indoor desk calibration, or walking simulation
  void manualStep({double stepMeters = defaultStepLengthM}) {
    _totalSteps++;
    stepForward(stepMeters);
  }

  /// Steps towards a specified world target coordinate
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

  void setPosition(Vector3 pos) {
    _currentPosition = pos.clone();
    _updateRotationFromSensors();
  }

  void resetPosition() {
    _currentPosition = Vector3.zero();
    _updateRotationFromSensors();
  }

  void resetSession() {
    _currentPosition = Vector3.zero();
    _totalSteps = 0;
    _stepPeak = false;
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
    await _gyroSubscription?.cancel();
    await _userAccelSubscription?.cancel();
    await _rawAccelSubscription?.cancel();
    await _accelSubscription?.cancel();
    _platformSubscription = null;
    _compassSubscription = null;
    _gyroSubscription = null;
    _userAccelSubscription = null;
    _rawAccelSubscription = null;
    _accelSubscription = null;
  }

  @override
  void dispose() {
    stop();
    _poseController.close();
    _anomalyController.close();
  }
}
