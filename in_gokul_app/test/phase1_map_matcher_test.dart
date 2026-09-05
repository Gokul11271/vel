import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:in_gokul_app/models/node.dart';
import 'package:in_gokul_app/models/edge.dart';
import 'package:in_gokul_app/models/graph.dart';
import 'package:in_gokul_app/algorithms/dijkstra.dart';
import 'package:in_gokul_app/algorithms/map_matcher.dart';
import 'package:in_gokul_app/services/world_alignment_service.dart';
import 'package:in_gokul_app/tracking/simulation_position_provider.dart';
import 'package:in_gokul_app/controllers/navigation_controller.dart';

void main() {
  group('Phase 1 — MapMatcher & Corridor Tolerance', () {
    test('Snaps point to segment and computes correct parametric progress t', () {
      final n1 = Node(id: 1, name: 'A', x: 0, y: 0, z: 0);
      final n2 = Node(id: 2, name: 'B', x: 0, y: 0, z: -10);
      final path = [n1, n2];

      // Point slightly to the right of corridor midpoint: (0.8, 0, -4.0)
      final rawPos = Vector3(0.8, 0, -4.0);
      final match = MapMatcher.projectOntoPath(rawPos, path, corridorWidthM: 2.4);

      expect(match, isNotNull);
      expect(match!.snappedPosition.x, closeTo(0.0, 0.001));
      expect(match.snappedPosition.y, closeTo(0.0, 0.001));
      expect(match.snappedPosition.z, closeTo(-4.0, 0.001));
      expect(match.t, closeTo(0.40, 0.01)); // 40% along segment
      expect(match.distanceToEdge, closeTo(0.8, 0.001));
      expect(match.isWithinCorridor, isTrue); // 0.8m <= 1.2m half-width
    });

    test('Correctly identifies points outside corridor boundary', () {
      final n1 = Node(id: 1, name: 'A', x: 0, y: 0, z: 0);
      final n2 = Node(id: 2, name: 'B', x: 10, y: 0, z: 0);
      final path = [n1, n2];

      // Point 2.0m perpendicular to corridor (corridor half-width is 1.2m)
      final rawPos = Vector3(5.0, 0, 2.0);
      final match = MapMatcher.projectOntoPath(rawPos, path, corridorWidthM: 2.4);

      expect(match, isNotNull);
      expect(match!.snappedPosition.x, closeTo(5.0, 0.001));
      expect(match.snappedPosition.z, closeTo(0.0, 0.001));
      expect(match.distanceToEdge, closeTo(2.0, 0.001));
      expect(match.isWithinCorridor, isFalse);
    });
  });

  group('Phase 1 — Decoupled Poses & Automatic Reroute in NavigationController', () {
    test('rawPose keeps raw coordinates while navigationPose snaps to corridor', () async {
      final n1 = Node(id: 1, name: 'Start', x: 0, y: 0, z: 0);
      final n2 = Node(id: 2, name: 'Hallway End', x: 0, y: 0, z: -10);

      final routeResult = DijkstraResult(path: [n1, n2], totalDistance: 10.0);
      final alignmentService = WorldAlignmentService();
      final positionProvider = SimulationPositionProvider();

      final controller = NavigationController(
        routeResult: routeResult,
        positionProvider: positionProvider,
        alignmentService: alignmentService,
        corridorWidthM: 2.4,
      );

      await positionProvider.start();
      controller.beginCalibration();
      controller.completeCalibration();

      // Simulate walking slightly to the right inside the corridor at (0.6, 0, -3.0)
      positionProvider.setPosition(x: 0.6, y: 0, z: -3.0, yawRadians: 0.0);
      await Future.delayed(const Duration(milliseconds: 15));

      // Raw pose preserves true sensor offset
      expect(controller.rawPose.position.x, closeTo(0.6, 0.01));
      expect(controller.rawPose.position.z, closeTo(-3.0, 0.01));

      // Navigation pose is cleanly snapped to corridor centerline (x = 0)
      expect(controller.navigationPose.position.x, closeTo(0.0, 0.05));
      expect(controller.navigationPose.position.z, closeTo(-3.0, 0.05));
      expect(controller.isInsideCorridor, isTrue);

      controller.dispose();
      positionProvider.dispose();
    });

    test('Automatic reroute recalculates Dijkstra path when straying off route', () async {
      final n1 = Node(id: 1, name: 'Start', x: 0, y: 0, z: 0);
      final n2 = Node(id: 2, name: 'North Hallway', x: 0, y: 0, z: -10);
      final n3 = Node(id: 3, name: 'East Corridor', x: 10, y: 0, z: 0);
      final n4 = Node(id: 4, name: 'Goal', x: 10, y: 0, z: -10);

      final graph = Graph(
        nodes: {1: n1, 2: n2, 3: n3, 4: n4},
        edges: [
          Edge(sourceId: 1, targetId: 2, weight: 10),
          Edge(sourceId: 2, targetId: 4, weight: 10),
          Edge(sourceId: 1, targetId: 3, weight: 10),
          Edge(sourceId: 3, targetId: 4, weight: 10),
        ],
      );

      // Initial route: 1 -> 2 -> 4
      final routeResult = DijkstraResult(path: [n1, n2, n4], totalDistance: 20.0);
      final alignmentService = WorldAlignmentService();
      final positionProvider = SimulationPositionProvider();

      bool rerouteTriggered = false;

      final controller = NavigationController(
        routeResult: routeResult,
        positionProvider: positionProvider,
        alignmentService: alignmentService,
        graph: graph,
        onRouteRecalculated: () => rerouteTriggered = true,
      );

      await positionProvider.start();
      controller.beginCalibration();
      controller.completeCalibration();

      // User walked off-route towards Node 3 at (9.0, 0, 0)
      for (int frame = 0; frame < 15; frame++) {
        positionProvider.setPosition(x: 9.0, y: 0, z: 0.0);
        await Future.delayed(const Duration(milliseconds: 5));
      }

      expect(rerouteTriggered, isTrue);
      // New path should be recalculated through Node 3 to Node 4
      expect(controller.path.map((n) => n.id).toList(), containsAllInOrder([3, 4]));

      controller.dispose();
      positionProvider.dispose();
    });
  });
}
