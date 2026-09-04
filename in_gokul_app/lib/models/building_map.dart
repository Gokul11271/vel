import 'node.dart';
import 'edge.dart';
import 'graph.dart';

/// Represents a complete mapped building: its identity, graph nodes and edges.
/// Used by the Mobile Mapper to serialise a walk-and-tap session, and by
/// JsonService to save/restore maps to device storage.
class BuildingMap {
  final String buildingId;
  final String buildingName;
  final int entranceNodeId;
  final List<Node> nodes;
  final List<Edge> edges;

  BuildingMap({
    required this.buildingId,
    required this.buildingName,
    required this.entranceNodeId,
    required this.nodes,
    required this.edges,
  });

  // ── Serialisation ──────────────────────────────────────────────────────────

  factory BuildingMap.fromJson(Map<String, dynamic> json) {
    final rawNodes = (json['nodes'] as List? ?? []);
    final rawEdges = (json['edges'] as List? ?? []);
    return BuildingMap(
      buildingId: json['buildingId'] as String? ?? 'unknown',
      buildingName: json['buildingName'] as String? ?? 'Unknown Building',
      entranceNodeId: json['entranceNodeId'] as int? ?? 0,
      nodes: rawNodes.map((n) => Node.fromJson(n as Map<String, dynamic>)).toList(),
      edges: rawEdges.map((e) => Edge.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'buildingId': buildingId,
        'buildingName': buildingName,
        'entranceNodeId': entranceNodeId,
        'nodes': nodes.map((n) => n.toJson()).toList(),
        'edges': edges.map((e) => e.toJson()).toList(),
      };

  // ── Conversion to Graph ───────────────────────────────────────────────────

  Graph toGraph() => Graph.fromNodesList(nodes, edgeList: edges.isEmpty ? null : edges);

  @override
  String toString() =>
      'BuildingMap($buildingId — ${nodes.length} nodes, ${edges.length} edges)';
}
