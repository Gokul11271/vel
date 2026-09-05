import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:in_gokul_app/models/node.dart';
import 'package:in_gokul_app/models/pose.dart';
import 'package:in_gokul_app/models/navigation_state.dart';
import 'package:in_gokul_app/algorithms/dijkstra.dart';
import 'package:in_gokul_app/algorithms/route_segment_generator.dart';
import 'package:in_gokul_app/services/world_alignment_service.dart';
import 'package:in_gokul_app/tracking/simulation_position_provider.dart';
import 'package:in_gokul_app/controllers/navigation_controller.dart';
import 'package:in_gokul_app/ar/ar_manager.dart';

void main() {
  group('Phase 3 — RouteSegmentGenerator (1.2m Breadcrumb Pipeline)', () {
    test('Generates equidistant breadcrumbs every 1.2m along a 6m corridor', () {
      final n1 = Node(id: 1, name: 'Entrance', x: 0, y: 0, z: 0);
      final n2 = Node(id: 2, name: 'Corridor End', x: 0, y: 0, z: -6.0);
      final path = [n1, n2];

      final breadcrumbs = RouteSegmentGenerator.generateBreadcrumbs(
        path,
        spacingM: 1.2,
      );

      // 6.0m / 1.2m = 5 intervals -> 6 points (0m, 1.2m, 2.4m, 3.6m, 4.8m, 6.0m)
      expect(breadcrumbs.length, equals(6));

      expect(breadcrumbs.first.jsonPosition.z, closeTo(0.0, 0.01));
      expect(breadcrumbs.first.distanceAlongPath, closeTo(0.0, 0.01));

      expect(breadcrumbs[1].jsonPosition.z, closeTo(-1.2, 0.01));
      expect(breadcrumbs[1].distanceAlongPath, closeTo(1.2, 0.01));

      expect(breadcrumbs.last.jsonPosition.z, closeTo(-6.0, 0.01));
      expect(breadcrumbs.last.distanceAlongPath, closeTo(6.0, 0.01));

      // Forward tangent should point North in JSON space (0, 0, -1)
      expect(breadcrumbs[2].forwardTangent.x, closeTo(0.0, 0.01));
      expect(breadcrumbs[2].forwardTangent.z, closeTo(-1.0, 0.01));
    });

    test('Generates multi-segment breadcrumbs with turn tangents across corridors', () {
      final n1 = Node(id: 1, name: 'Start', x: 0, y: 0, z: 0);
      final n2 = Node(id: 2, name: 'Corner', x: 0, y: 0, z: -4.0);
      final n3 = Node(id: 3, name: 'Room', x: 4.0, y: 0, z: -4.0); // 90° East turn
      final path = [n1, n2, n3];

      final breadcrumbs = RouteSegmentGenerator.generateBreadcrumbs(
        path,
        spacingM: 1.0,
      );

      expect(breadcrumbs.isNotEmpty, isTrue);

      // Segment 0 breadcrumbs (moving -Z)
      final seg0 = breadcrumbs.where((b) => b.segmentIndex == 0).toList();
      expect(seg0.first.forwardTangent.z, closeTo(-1.0, 0.01));

      // Segment 1 breadcrumbs (moving +X)
      final seg1 = breadcrumbs.where((b) => b.segmentIndex == 1).toList();
      expect(seg1.first.forwardTangent.x, closeTo(1.0, 0.01));
    });
  });

  group('Phase 4 — 3-Tier Tracking State Machine (GOOD / LIMITED / LOST)', () {
    test('ARManager synchronizes route breadcrumbs and responds to tracking state changes', () async {
      final n1 = Node(id: 1, name: 'Start', x: 0, y: 0, z: 0);
      final n2 = Node(id: 2, name: 'Next', x: 0, y: 0, z: -3.0);
      final n3 = Node(id: 3, name: 'Goal', x: 0, y: 0, z: -6.0);

      final routeResult = DijkstraResult(path: [n1, n2, n3], totalDistance: 6.0);
      final alignmentService = WorldAlignmentService();
      final positionProvider = SimulationPositionProvider();

      final controller = NavigationController(
        routeResult: routeResult,
        positionProvider: positionProvider,
        alignmentService: alignmentService,
      );

      final arManager = ARManager(
        positionProvider: positionProvider,
        alignmentService: alignmentService,
      );

      await positionProvider.start();
      await arManager.initializeSession();

      controller.beginCalibration();
      controller.completeCalibration();

      arManager.setRoute(controller.path, currentStepIndex: 0);
      arManager.setTargetNode(controller.nextTargetNode, currentStepIndex: 0);

      expect(arManager.breadcrumbs.length, greaterThan(0));
      expect(arManager.activeSegmentIndex, equals(0));

      // 1. GOOD tracking
      positionProvider.setPosition(
        x: 0,
        y: 0,
        z: -1.0,
        trackingState: TrackingState.good,
      );
      await Future.delayed(const Duration(milliseconds: 15));
      expect(controller.trackingState, equals(TrackingState.good));

      // 2. LIMITED tracking
      positionProvider.setPosition(
        x: 0,
        y: 0,
        z: -1.0,
        trackingState: TrackingState.limited,
      );
      await Future.delayed(const Duration(milliseconds: 15));
      expect(controller.trackingState, equals(TrackingState.limited));

      // 3. LOST tracking
      positionProvider.setPosition(
        x: 0,
        y: 0,
        z: -1.0,
        trackingState: TrackingState.lost,
      );
      await Future.delayed(const Duration(milliseconds: 15));
      expect(controller.state, equals(NavigationState.trackingLost));

      controller.dispose();
      arManager.dispose();
      positionProvider.dispose();
    });
  });

  group('Phase 2 — QR World Origin Alignment', () {
    test('Aligns world origin and heading with preset azimuth from entrance QR', () {
      final service = WorldAlignmentService();
      final entranceNode = Node(id: 1, name: 'Main Gate', x: 10, y: 0, z: 20);
      final nextNode = Node(id: 2, name: 'Foyer', x: 10, y: 0, z: 10);

      // Scanned QR sets initial heading (e.g. 90° East / pi/2 radians)
      final pose = Pose.fromValues(x: 0, y: 0, z: 0, yawRadians: pi / 2);

      service.calibrate(
        startNode: entranceNode,
        currentPose: pose,
        targetNode: nextNode,
      );

      expect(service.isCalibrated, isTrue);

      // Distance from entrance to foyer in world coordinates matches JSON distance (10m)
      final dist = service.getDistanceToNode(Vector3.zero(), nextNode);
      expect(dist, closeTo(10.0, 0.01));
    });
  });
}
