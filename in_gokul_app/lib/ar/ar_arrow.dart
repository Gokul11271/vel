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
  double _pitchAngleRadians = 0.0;

  Vector3 get position => _position.clone();
  Quaternion get rotation => _rotation.clone();
  double get scale => _scale;
  Color get color => _color;
  double get distanceToTarget => _distanceToTarget;
  double get yawAngleRadians => _yawAngleRadians;
  double get relativeBearingRadians => _relativeBearingRadians;
  double get relativeBearingDegrees => _relativeBearingRadians * (180.0 / pi);
  double get pitchAngleRadians => _pitchAngleRadians;

  /// Updates the 3D arrow position and orientation towards [targetWorldPos]
  /// given the user's current [cameraPose].
  ///
  /// Uses the full camera quaternion to compute the forward vector, then
  /// computes the quaternion that rotates the forward vector toward the target.
  /// This correctly accounts for phone tilt (pitch), not just yaw.
  void update({
    required Pose cameraPose,
    required Vector3 targetWorldPos,
    double forwardOffsetMeters = 1.5,
  }) {
    final cameraPos = cameraPose.position;
    final toTarget = targetWorldPos - cameraPos;
    _distanceToTarget = toTarget.length;

    // --- Yaw / horizontal bearing (for HUD display) ---
    _yawAngleRadians = atan2(toTarget.x, -toTarget.z);

    // --- Full camera quaternion forward vector ---
    // Camera looks in -Z in OpenGL/Flutter convention
    final cameraForward = cameraPose.rotation.rotated(Vector3(0, 0, -1));

    // --- Relative bearing (for turn instruction HUD) ---
    final cameraYaw = atan2(cameraForward.x, -cameraForward.z);
    var rel = _yawAngleRadians - cameraYaw;
    while (rel > pi) {
      rel -= 2 * pi;
    }
    while (rel < -pi) {
      rel += 2 * pi;
    }
    _relativeBearingRadians = rel;

    // --- Full 3D quaternion rotation: forward -> target direction ---
    if (_distanceToTarget > 0.01) {
      final targetDir = toTarget.normalized();
      final forwardNorm = cameraForward.length2 > 0.0001
          ? cameraForward.normalized()
          : Vector3(0, 0, -1);

      // Pitch angle for display / debug
      _pitchAngleRadians = asin(targetDir.y.clamp(-1.0, 1.0));

      // Compute rotation quaternion from forward to target direction
      _rotation = _quaternionFromTwoVectors(forwardNorm, targetDir);
    } else {
      _rotation = cameraPose.rotation.clone();
    }

    // --- Arrow position: 1.5m ahead of camera along horizontal bearing ---
    // We place it horizontally so it stays in the camera frustum naturally
    final forwardDir = Vector3(sin(_yawAngleRadians), 0, -cos(_yawAngleRadians));
    _position = cameraPos + (forwardDir * forwardOffsetMeters);

    // --- Dynamic color & scale based on distance ---
    if (_distanceToTarget < 1.0) {
      _color = Colors.greenAccent;
      _scale = 0.85;
    } else if (_distanceToTarget < 3.0) {
      _color = Colors.cyanAccent;
      _scale = 1.0;
    } else {
      _color = Colors.deepPurpleAccent;
      _scale = 1.15;
    }
  }

  /// Computes the shortest-arc quaternion rotating [from] to [to].
  /// Falls back to identity if vectors are parallel or anti-parallel.
  static Quaternion _quaternionFromTwoVectors(Vector3 from, Vector3 to) {
    final dot = from.dot(to).clamp(-1.0, 1.0);

    // Vectors already aligned
    if (dot > 0.9999) return Quaternion.identity();

    // Vectors are opposite — rotate 180° around any perpendicular axis
    if (dot < -0.9999) {
      var perp = Vector3(1, 0, 0);
      if (from.x.abs() > 0.9) perp = Vector3(0, 1, 0);
      return Quaternion.axisAngle(perp, pi);
    }

    final axis = from.cross(to)..normalize();
    final angle = acos(dot);
    return Quaternion.axisAngle(axis, angle);
  }
}
