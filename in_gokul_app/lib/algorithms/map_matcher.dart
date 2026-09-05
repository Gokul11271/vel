import 'package:vector_math/vector_math_64.dart';
import '../models/graph.dart';
import '../models/node.dart';
import '../models/edge.dart';

/// Result from map-matching: the snapped position, edge, and corridor metrics.
class MapMatchResult {
  /// Position projected onto the nearest graph edge (metres, JSON coordinate space).
  final Vector3 snappedPosition;

  /// The edge this position was snapped to.
  final Edge edge;

  /// Perpendicular distance from the raw position to the edge centerline (metres).
  final double distanceToEdge;

  /// Parametric progress along the segment from source node (0.0) to target node (1.0).
  final double t;

  /// Whether the position falls within the corridor tolerance boundary (half-width).
  final bool isWithinCorridor;

  const MapMatchResult({
    required this.snappedPosition,
    required this.edge,
    required this.distanceToEdge,
    required this.t,
    required this.isWithinCorridor,
  });
}

/// Projects a raw position onto corridor segments and graph edges.
/// Provides active corridor locking and off-route detection.
class MapMatcher {
  /// Standard architectural hallway width (2.4 metres, 1.2m half-width from centerline).
  static const double defaultCorridorWidthM = 2.4;

  /// Maximum perpendicular distance (metres) beyond corridor bounds before triggering reroute.
  static const double offRouteThresholdM = 3.5;

  /// Projects [position] onto the active navigation [path] segments first.
  /// Prioritizes current route before checking the entire graph.
  static MapMatchResult? projectOntoPath(
    Vector3 position,
    List<Node> path, {
    double corridorWidthM = defaultCorridorWidthM,
  }) {
    if (path.length < 2) return null;

    MapMatchResult? best;
    double bestDist = double.infinity;
    final halfWidth = corridorWidthM / 2.0;

    for (int i = 0; i < path.length - 1; i++) {
      final n1 = path[i];
      final n2 = path[i + 1];

      final p1 = Vector3(n1.x, n1.y, n1.z);
      final p2 = Vector3(n2.x, n2.y, n2.z);

      final ab = p2 - p1;
      final lenSq = ab.length2;
      final t = lenSq < 1e-9 ? 0.0 : ((position - p1).dot(ab) / lenSq).clamp(0.0, 1.0);
      final projected = p1 + ab * t;
      final dist = (position - projected).length;

      if (dist < bestDist) {
        bestDist = dist;
        best = MapMatchResult(
          snappedPosition: projected,
          edge: Edge(
            sourceId: n1.id,
            targetId: n2.id,
            weight: n1.distanceTo(n2),
          ),
          distanceToEdge: dist,
          t: t,
          isWithinCorridor: dist <= halfWidth,
        );
      }
    }

    return best;
  }

  /// Projects [position] (JSON coordinate space) onto the nearest edge in [graph].
  static MapMatchResult? project(
    Vector3 position,
    Graph graph, {
    double corridorWidthM = defaultCorridorWidthM,
  }) {
    if (graph.edges.isEmpty) return null;

    MapMatchResult? best;
    double bestDist = double.infinity;
    final halfWidth = corridorWidthM / 2.0;

    for (final edge in graph.edges) {
      final n1 = graph.nodes[edge.sourceId];
      final n2 = graph.nodes[edge.targetId];
      if (n1 == null || n2 == null) continue;

      final p1 = Vector3(n1.x, n1.y, n1.z);
      final p2 = Vector3(n2.x, n2.y, n2.z);

      final ab = p2 - p1;
      final lenSq = ab.length2;
      final t = lenSq < 1e-9 ? 0.0 : ((position - p1).dot(ab) / lenSq).clamp(0.0, 1.0);
      final projected = p1 + ab * t;
      final dist = (position - projected).length;

      if (dist < bestDist) {
        bestDist = dist;
        best = MapMatchResult(
          snappedPosition: projected,
          edge: edge,
          distanceToEdge: dist,
          t: t,
          isWithinCorridor: dist <= halfWidth,
        );
      }
    }

    return best;
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
