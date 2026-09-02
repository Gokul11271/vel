import 'node.dart';
import 'edge.dart';

class Graph {
  final Map<int, Node> nodes;
  final List<Edge> edges;

  Graph({
    required this.nodes,
    required this.edges,
  });

  /// Automatically constructs graph edges from a list of nodes.
  /// If explicit edges are not present in JSON, it connects sequential nodes.
  factory Graph.fromNodesList(List<Node> nodeList, {List<Edge>? edgeList}) {
    final Map<int, Node> nodeMap = {for (var n in nodeList) n.id: n};
    final List<Edge> finalEdges = List.from(edgeList ?? []);

    if (finalEdges.isEmpty && nodeList.length > 1) {
      for (int i = 0; i < nodeList.length - 1; i++) {
        final n1 = nodeList[i];
        final n2 = nodeList[i + 1];
        final dist = n1.distanceTo(n2);
        // Add bidirectional edges
        finalEdges.add(Edge(sourceId: n1.id, targetId: n2.id, weight: dist));
        finalEdges.add(Edge(sourceId: n2.id, targetId: n1.id, weight: dist));
      }
    }

    return Graph(nodes: nodeMap, edges: finalEdges);
  }

  /// Get all adjacent edges for a given node ID
  List<Edge> getNeighbors(int nodeId) {
    return edges.where((e) => e.sourceId == nodeId).toList();
  }
}
