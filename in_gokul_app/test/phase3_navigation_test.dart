import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:in_gokul_app/models/node.dart';
import 'package:in_gokul_app/models/pose.dart';
import 'package:in_gokul_app/models/navigation_state.dart';
import 'package:in_gokul_app/services/world_alignment_service.dart';
import 'package:in_gokul_app/tracking/simulation_position_provider.dart';
import 'package:in_gokul_app/controllers/navigation_controller.dart';
import 'package:in_gokul_app/algorithms/dijkstra.dart';
import 'package:in_gokul_app/ar/ar_arrow.dart';

void main() {
  group('Phase 3 — WorldAlignmentService & Rotation Matrix', () {
    test('World alignment translates and rotates JSON coordinates correctly', () {
      final service = WorldAlignmentService();
      final startNode = Node(id: 1, name: 'Entrance', x: 0, y: 0, z: 0);
      final nextNode = Node(id: 2, name: 'Turn 1', x: 0, y: 0, z: -10); // 10m North in JSON

      // Simulate camera pose at origin facing North (yaw = 0)
      final cameraPose = Pose.fromValues(x: 0, y: 0, z: 0, yawRadians: 0);

      service.calibrate(startNode: startNode, currentPose: cameraPose, targetNode: nextNode);
      expect(service.isCalibrated, isTrue);

      final worldPos = service.transformJsonToWorld(nextNode);
      // In AR coordinates facing North, delta should be (0, 0, -10)
      expect(worldPos.x, closeTo(0, 0.01));
      expect(worldPos.y, closeTo(0, 0.01));
      expect(worldPos.z, closeTo(-10, 0.01));

      // Distance should be exactly 10m
      final dist = service.getDistanceToNode(Vector3.zero(), nextNode);
      expect(dist, closeTo(10.0, 0.01));
    });

    test('Rotation matrix preserves Euclidean distances under 90 degree corridor turn', () {
      final service = WorldAlignmentService();
      final startNode = Node(id: 1, name: 'Start', x: 2, y: 1, z: 5);
      final destNode = Node(id: 2, name: 'Dest', x: 2, y: 1, z: 15); // Distance = 10m

      // Phone is facing 90 degrees (East)
      final cameraPose = Pose.fromValues(x: 1, y: 0, z: 1, yawRadians: pi / 2);

      service.calibrate(startNode: startNode, currentPose: cameraPose);

      final worldPos = service.transformJsonToWorld(destNode);
      final dist = cameraPose.position.distanceTo(worldPos);

      // Distance from start to dest in world space must equal 10m
      expect(dist, closeTo(10.0, 0.01));
    });
  });

  group('Phase 3 — Navigation State Machine & Adaptive Arrival Thresholds', () {
    test('State machine transitions properly from calibration to destination arrival', () async {
      final n1 = Node(id: 1, name: 'Start', x: 0, y: 0, z: 0);
      final n2 = Node(id: 2, name: 'Waypoint', x: 0, y: 0, z: -2);
      final n3 = Node(id: 3, name: 'Final Room', x: 0, y: 0, z: -5);

      final routeResult = DijkstraResult(path: [n1, n2, n3], totalDistance: 5.0);

      final alignmentService = WorldAlignmentService();
      final positionProvider = SimulationPositionProvider();

      final controller = NavigationController(
        routeResult: routeResult,
        positionProvider: positionProvider,
        alignmentService: alignmentService,
        waypointArrivalThreshold: 0.8,
        destinationArrivalThreshold: 1.5,
      );

      await positionProvider.start();

      expect(controller.state, equals(NavigationState.waitingForTracking));

      // Calibrate
      controller.beginCalibration();
      expect(controller.state, equals(NavigationState.calibrating));

      controller.completeCalibration();
      expect(controller.state, equals(NavigationState.navigating));
      expect(controller.currentNode?.id, equals(1));
      expect(controller.nextTargetNode?.id, equals(2));

      // Step towards waypoint (N2 at z = -2)
      positionProvider.setPosition(x: 0, y: 0, z: -1.3); // Within 0.8m of N2 (dist = 0.7m)
      await Future.delayed(const Duration(milliseconds: 10));

      expect(controller.currentNode?.id, equals(2));
      expect(controller.nextTargetNode?.id, equals(3));

      // Step towards destination (N3 at z = -5)
      positionProvider.setPosition(x: 0, y: 0, z: -3.8); // Within 1.5m adaptive destination threshold (dist = 1.2m)
      await Future.delayed(const Duration(milliseconds: 10));

      expect(controller.state, equals(NavigationState.destinationReached));
      expect(controller.isFinished, isTrue);

      controller.dispose();
      positionProvider.dispose();
    });
  });

  group('Phase 3 — ARArrow 3D Calculations & Relative Bearing', () {
    test('ARArrow computes correct relative bearing when target is to the right', () {
      final arrow = ARArrow();
      // User at (0, 0, 0) facing forward (yaw = 0)
      final userPose = Pose.fromValues(x: 0, y: 0, z: 0, yawRadians: 0);
      // Target is directly to the right at (5, 0, 0)
      final targetPos = Vector3(5, 0, 0);

      arrow.update(cameraPose: userPose, targetWorldPos: targetPos);

      expect(arrow.distanceToTarget, closeTo(5.0, 0.01));
      expect(arrow.relativeBearingDegrees, closeTo(90.0, 0.1));
    });
  });
}
