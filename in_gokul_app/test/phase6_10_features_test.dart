import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:in_gokul_app/models/node.dart';
import 'package:in_gokul_app/models/edge.dart';
import 'package:in_gokul_app/models/building_map.dart';
import 'package:in_gokul_app/algorithms/route_segment_generator.dart';

void main() {
  group('Phase 6 & 8: 1.0m World-Anchored Highway & Breadcrumb Generator', () {
    test('interpolates points along straight corridor at ~1.0m intervals', () {
      final p1 = Node(id: 0, name: 'Entrance', x: 0, y: 0, z: 0);
      final p2 = Node(id: 1, name: 'Hallway End', x: 0, y: 0, z: 5.0);

      final crumbs = RouteSegmentGenerator.generateBreadcrumbs([p1, p2]);

      expect(crumbs.isNotEmpty, isTrue);
      // For a 5.0m leg with 1.0m spacing, should yield 6 points (0m, 1m, 2m, 3m, 4m, 5m)
      expect(crumbs.length, equals(6));
      expect(crumbs.first.distanceAlongPath, closeTo(0.0, 1e-4));
      expect(crumbs.last.distanceAlongPath, closeTo(5.0, 1e-4));
      expect(crumbs.last.jsonPosition.z, closeTo(5.0, 1e-4));
    });

    test('multi-segment L-shaped corner interpolation connects smoothly', () {
      final n1 = Node(id: 0, name: 'A', x: 0, y: 0, z: 0);
      final n2 = Node(id: 1, name: 'B', x: 0, y: 0, z: 4.0); // 4m North
      final n3 = Node(id: 2, name: 'C', x: 3.0, y: 0, z: 4.0); // 3m East

      final crumbs = RouteSegmentGenerator.generateBreadcrumbs([n1, n2, n3]);

      // Total path distance = 4.0 + 3.0 = 7.0m
      expect(crumbs.first.jsonPosition, equals(Vector3(0, 0, 0)));
      expect(crumbs.last.jsonPosition, equals(Vector3(3.0, 0, 4.0)));
      expect(crumbs.last.distanceAlongPath, closeTo(7.0, 1e-4));
    });
  });

  group('Phase 7: Mapper Auto-Edge & Graph Construction', () {
    test('auto-builds bidirectional edges with correct Euclidean distances', () {
      final nodes = [
        Node(id: 0, name: 'Entrance', x: 0, y: 0, z: 0),
        Node(id: 1, name: 'Corner', x: 3.0, y: 0, z: 4.0), // dist = 5.0
        Node(id: 2, name: 'Office', x: 3.0, y: 0, z: 10.0), // dist = 6.0
      ];

      final edges = <Edge>[];
      for (int i = 0; i < nodes.length - 1; i++) {
        final n1 = nodes[i];
        final n2 = nodes[i + 1];
        final dx = n1.x - n2.x;
        final dy = n1.y - n2.y;
        final dz = n1.z - n2.z;
        final dist = sqrt(dx * dx + dy * dy + dz * dz);
        edges.add(Edge(sourceId: n1.id, targetId: n2.id, weight: dist));
        edges.add(Edge(sourceId: n2.id, targetId: n1.id, weight: dist));
      }

      expect(edges.length, equals(4)); // 2 pairs of bidirectional edges
      expect(edges[0].sourceId, equals(0));
      expect(edges[0].targetId, equals(1));
      expect(edges[0].weight, closeTo(5.0, 1e-4));

      expect(edges[1].sourceId, equals(1));
      expect(edges[1].targetId, equals(0));
      expect(edges[1].weight, closeTo(5.0, 1e-4));

      expect(edges[2].sourceId, equals(1));
      expect(edges[2].targetId, equals(2));
      expect(edges[2].weight, closeTo(6.0, 1e-4));

      final map = BuildingMap(
        buildingId: 'b_01',
        buildingName: 'Test Hall',
        entranceNodeId: 0,
        nodes: nodes,
        edges: edges,
      );

      final json = map.toJson();
      expect(json['buildingId'], equals('b_01'));
      expect((json['nodes'] as List).length, equals(3));
      expect((json['edges'] as List).length, equals(4));
    });
  });

  group('Phase 9: Turn Angle & Dynamic Countdown Trigonometry', () {
    double calculateTurnDeg(Node p0, Node p1, Node p2) {
      final v1x = p1.x - p0.x;
      final v1z = p1.z - p0.z;
      final v2x = p2.x - p1.x;
      final v2z = p2.z - p1.z;

      final angle1 = atan2(v1x, -v1z);
      final angle2 = atan2(v2x, -v2z);
      var turnDiff = angle2 - angle1;
      while (turnDiff > pi) {
        turnDiff -= 2 * pi;
      }
      while (turnDiff < -pi) {
        turnDiff += 2 * pi;
      }
      return turnDiff * (180.0 / pi);
    }

    test('detects right 90 degree turn correctly', () {
      // Walking along negative Z (North), then turning positive X (East)
      final p0 = Node(id: 0, name: 'A', x: 0, y: 0, z: 0);
      final p1 = Node(id: 1, name: 'B', x: 0, y: 0, z: -5.0);
      final p2 = Node(id: 2, name: 'C', x: 5.0, y: 0, z: -5.0);

      final deg = calculateTurnDeg(p0, p1, p2);
      expect(deg, closeTo(90.0, 1.0));
    });

    test('detects left 90 degree turn correctly', () {
      // Walking along negative Z (North), then turning negative X (West)
      final p0 = Node(id: 0, name: 'A', x: 0, y: 0, z: 0);
      final p1 = Node(id: 1, name: 'B', x: 0, y: 0, z: -5.0);
      final p2 = Node(id: 2, name: 'C', x: -5.0, y: 0, z: -5.0);

      final deg = calculateTurnDeg(p0, p1, p2);
      expect(deg, closeTo(-90.0, 1.0));
    });

    test('detects straight continuation correctly (< 10 deg deviation)', () {
      final p0 = Node(id: 0, name: 'A', x: 0, y: 0, z: 0);
      final p1 = Node(id: 1, name: 'B', x: 0, y: 0, z: -5.0);
      final p2 = Node(id: 2, name: 'C', x: 0, y: 0, z: -10.0);

      final deg = calculateTurnDeg(p0, p1, p2);
      expect(deg.abs(), closeTo(0.0, 1e-4));
    });
  });
}
