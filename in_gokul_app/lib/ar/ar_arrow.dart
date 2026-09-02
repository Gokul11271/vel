import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import '../models/pose.dart';

class ARArrow {
  Vector3 _position = Vector3(0, 0, -1.5);
  Quaternion _rotation = Quaternion.identity();
  double _scale = 1.0;
  Color _color = Colors.cyanAccent;
  double _distanceToTarget = 0.0;
  double _yawAngleRadians = 0.0;
  double _relativeBearingRadians = 0.0;

  Vector3 get position => _position.clone();
  Quaternion get rotation => _rotation.clone();
  double get scale => _scale;
  Color get color => _color;
  double get distanceToTarget => _distanceToTarget;
  double get yawAngleRadians => _yawAngleRadians;
  double get relativeBearingRadians => _relativeBearingRadians;
  double get relativeBearingDegrees => _relativeBearingRadians * (180.0 / pi);

  /// Updates the 3D arrow position and orientation towards [targetWorldPos]
  /// given the user's current [cameraPose].
  void update({
    required Pose cameraPose,
    required Vector3 targetWorldPos,
    double forwardOffsetMeters = 1.5,
  }) {
    final cameraPos = cameraPose.position;
    final toTarget = targetWorldPos - cameraPos;
    _distanceToTarget = toTarget.length;

    // Calculate world yaw angle towards target
    _yawAngleRadians = atan2(toTarget.x, -toTarget.z);

    // Calculate relative bearing relative to camera heading
    final cameraYaw = cameraPose.yawRadians;
    var rel = _yawAngleRadians - cameraYaw;
    while (rel > pi) {
      rel -= 2 * pi;
    }
    while (rel < -pi) {
      rel += 2 * pi;
    }
    _relativeBearingRadians = rel;

    // Compute 3D rotation quaternion pointing towards target
    _rotation = Quaternion.axisAngle(Vector3(0, 1, 0), _yawAngleRadians);

    // Place the arrow 1.5m ahead of camera
    final forwardDir = Vector3(sin(_yawAngleRadians), 0, -cos(_yawAngleRadians));
    _position = cameraPos + (forwardDir * forwardOffsetMeters);

    // Dynamic color & scale based on distance
    if (_distanceToTarget < 1.0) {
      _color = Colors.greenAccent;
      _scale = 0.9;
    } else if (_distanceToTarget < 3.0) {
      _color = Colors.cyanAccent;
      _scale = 1.0;
    } else {
      _color = Colors.deepPurpleAccent;
      _scale = 1.1;
    }
  }
}
