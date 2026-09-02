import '../models/node.dart';
import '../models/graph.dart';

class DijkstraResult {
  final List<Node> path;
  final double totalDistance;

  DijkstraResult({required this.path, required this.totalDistance});
}

class Dijkstra {
  static DijkstraResult findShortestPath(Graph graph, int startNodeId, int targetNodeId) {
    if (!graph.nodes.containsKey(startNodeId) || !graph.nodes.containsKey(targetNodeId)) {
      return DijkstraResult(path: [], totalDistance: double.infinity);
    }

    final Map<int, double> distances = {};
    final Map<int, int?> previous = {};
    final Set<int> unvisited = Set.from(graph.nodes.keys);

    for (var nodeId in graph.nodes.keys) {
      distances[nodeId] = double.infinity;
      previous[nodeId] = null;
    }
    distances[startNodeId] = 0.0;

    while (unvisited.isNotEmpty) {
      int? current;
      double minDistance = double.infinity;

      for (var nodeId in unvisited) {
        if (distances[nodeId]! < minDistance) {
          minDistance = distances[nodeId]!;
          current = nodeId;
        }
      }

      if (current == null || minDistance == double.infinity) break;
      if (current == targetNodeId) break;

      unvisited.remove(current);

      for (var edge in graph.getNeighbors(current)) {
        if (!unvisited.contains(edge.targetId)) continue;
        final alt = distances[current]! + edge.weight;
        if (alt < distances[edge.targetId]!) {
          distances[edge.targetId] = alt;
          previous[edge.targetId] = current;
        }
      }
    }

    final List<Node> path = [];
    int? curr = targetNodeId;
    while (curr != null) {
      final node = graph.nodes[curr];
      if (node != null) {
        path.insert(0, node);
      }
      curr = previous[curr];
    }

    if (path.isEmpty || path.first.id != startNodeId) {
      return DijkstraResult(path: [], totalDistance: double.infinity);
    }

    return DijkstraResult(path: path, totalDistance: distances[targetNodeId]!);
  }
}
