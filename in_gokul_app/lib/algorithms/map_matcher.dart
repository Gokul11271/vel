import 'package:vector_math/vector_math_64.dart';
import '../models/graph.dart';
import '../models/node.dart';
import '../models/edge.dart';

/// Result from map-matching: the snapped position and the edge it lies on.
class MapMatchResult {
  /// Position projected onto the nearest graph edge (metres, JSON coordinate space).
  final Vector3 snappedPosition;

  /// The edge this position was snapped to.
  final Edge edge;

  /// Perpendicular distance from the raw position to the edge (metres).
  final double distanceToEdge;

  const MapMatchResult({
    required this.snappedPosition,
    required this.edge,
    required this.distanceToEdge,
  });
}

/// Projects a raw position onto the nearest graph edge — exactly like
/// Google Maps snapping to roads.
///
/// Algorithm (per edge N1→N2):
///   t = clamp( dot(P-N1, N2-N1) / |N2-N1|², 0, 1 )
///   projected = N1 + t*(N2-N1)
///   dist = |P - projected|
/// The edge with the smallest dist wins.
class MapMatcher {
  /// Maximum perpendicular distance (metres) before a position is considered
  /// off-route. Callers can use this constant for their threshold checks.
  static const double offRouteThresholdM = 4.0;

  /// Projects [position] (JSON coordinate space) onto the nearest edge of [graph].
  /// Returns null if the graph has no edges.
  static MapMatchResult? project(Vector3 position, Graph graph) {
    if (graph.edges.isEmpty) return null;

    MapMatchResult? best;
    double bestDist = double.infinity;

    for (final edge in graph.edges) {
      final n1 = graph.nodes[edge.sourceId];
      final n2 = graph.nodes[edge.targetId];
      if (n1 == null || n2 == null) continue;

      final p1 = Vector3(n1.x, n1.y, n1.z);
      final p2 = Vector3(n2.x, n2.y, n2.z);

      final projected = _projectOntoSegment(position, p1, p2);
      final dist = (position - projected).length;

      if (dist < bestDist) {
        bestDist = dist;
        best = MapMatchResult(
          snappedPosition: projected,
          edge: edge,
          distanceToEdge: dist,
        );
      }
    }

    return best;
  }

  /// Projects point [p] onto line segment [a]→[b], clamped to [0,1].
  static Vector3 _projectOntoSegment(Vector3 p, Vector3 a, Vector3 b) {
    final ab = b - a;
    final lenSq = ab.length2;
    if (lenSq < 1e-9) return a.clone(); // degenerate edge

    final t = ((p - a).dot(ab) / lenSq).clamp(0.0, 1.0);
    return a + ab * t;
  }

  /// Returns the nearest [Node] in [graph] to the given [position].
  static Node? nearestNode(Vector3 position, Graph graph) {
    Node? best;
    double bestDist = double.infinity;
    for (final node in graph.nodes.values) {
      final d = (position - Vector3(node.x, node.y, node.z)).length;
      if (d < bestDist) {
        bestDist = d;
        best = node;
      }
    }
    return best;
  }
}
