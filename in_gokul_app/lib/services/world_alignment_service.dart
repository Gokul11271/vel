import 'dart:math';
import 'package:vector_math/vector_math_64.dart';
import '../models/node.dart';
import '../models/pose.dart';

class WorldAlignmentService {
  Node? _startNode;
  Vector3 _anchorPosition = Vector3.zero();
  double _anchorYaw = 0.0; // Rotation theta in radians
  Matrix3 _rotationMatrix = Matrix3.identity();
  Matrix3 _inverseRotationMatrix = Matrix3.identity();
  bool _isCalibrated = false;

  bool get isCalibrated => _isCalibrated;
  Node? get startNode => _startNode;
  Vector3 get anchorPosition => _anchorPosition.clone();
  double get anchorYaw => _anchorYaw;
  Matrix3 get rotationMatrix => _rotationMatrix.clone();

  /// Calibrates world alignment at a start node using current device pose.
  /// If [targetNode] is provided, aligns JSON corridor vector to AR camera heading.
  void calibrate({
    required Node startNode,
    required Pose currentPose,
    Node? targetNode,
  }) {
    _startNode = startNode;
    _anchorPosition = currentPose.position.clone();

    final currentCameraYaw = currentPose.yawRadians;

    if (targetNode != null) {
      // JSON vector from start to target
      final dx = targetNode.x - startNode.x;
      final dz = targetNode.z - startNode.z;
      final jsonHeading = atan2(dx, -dz);

      // Delta rotation to align JSON vector to AR camera forward direction
      _anchorYaw = currentCameraYaw - jsonHeading;
    } else {
      _anchorYaw = currentCameraYaw;
    }

    _rotationMatrix = Matrix3.rotationY(_anchorYaw);
    _inverseRotationMatrix = Matrix3.rotationY(-_anchorYaw);
    _isCalibrated = true;
  }

  /// Transforms a 3D point from JSON Map coordinates into AR World coordinates:
  /// P_world = P_anchor + R_y(theta) * (P_json - P_start)
  Vector3 transformJsonToWorld(Node node) {
    if (!_isCalibrated || _startNode == null) {
      return Vector3(node.x, node.y, node.z);
    }

    final localJsonDelta = Vector3(
      node.x - _startNode!.x,
      node.y - _startNode!.y,
      node.z - _startNode!.z,
    );

    final rotatedDelta = _rotationMatrix.transformed(localJsonDelta);
    return _anchorPosition + rotatedDelta;
  }

  /// Inverse transformation: AR World coordinates to JSON Map coordinates
  Vector3 transformWorldToJson(Vector3 worldPos) {
    if (!_isCalibrated || _startNode == null) {
      return worldPos.clone();
    }

    final delta = worldPos - _anchorPosition;
    final rotatedBack = _inverseRotationMatrix.transformed(delta);
    return Vector3(
      _startNode!.x + rotatedBack.x,
      _startNode!.y + rotatedBack.y,
      _startNode!.z + rotatedBack.z,
    );
  }

  /// Calculates 3D distance between current AR world position and a target node in map
  double getDistanceToNode(Vector3 currentWorldPos, Node targetNode) {
    final targetWorld = transformJsonToWorld(targetNode);
    return currentWorldPos.distanceTo(targetWorld);
  }

  /// Calculates horizontal bearing / yaw angle (in radians) towards target node
  double getBearingToNode(Vector3 currentWorldPos, Node targetNode) {
    final targetWorld = transformJsonToWorld(targetNode);
    final dx = targetWorld.x - currentWorldPos.x;
    final dz = targetWorld.z - currentWorldPos.z;
    return atan2(dx, -dz);
  }

  /// Gets normalized 3D direction vector from current position to target node
  Vector3 getDirectionToNode(Vector3 currentWorldPos, Node targetNode) {
    final targetWorld = transformJsonToWorld(targetNode);
    final dir = targetWorld - currentWorldPos;
    if (dir.length2 > 0.0001) {
      dir.normalize();
    }
    return dir;
  }

  void reset() {
    _startNode = null;
    _anchorPosition = Vector3.zero();
    _anchorYaw = 0.0;
    _rotationMatrix = Matrix3.identity();
    _inverseRotationMatrix = Matrix3.identity();
    _isCalibrated = false;
  }
}
