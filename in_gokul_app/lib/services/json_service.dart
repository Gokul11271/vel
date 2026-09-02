import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/node.dart';
import '../models/edge.dart';
import '../models/graph.dart';

class JsonService {
  /// Loads navigation data from assets/navigation.json
  static Future<Graph> loadNavigationGraph({String assetPath = 'assets/navigation.json'}) async {
    final String jsonString = await rootBundle.loadString(assetPath);
    final dynamic decoded = jsonDecode(jsonString);

    if (decoded is List) {
      // Direct array of nodes
      final List<Node> nodes = decoded.map((item) => Node.fromJson(item as Map<String, dynamic>)).toList();
      return Graph.fromNodesList(nodes);
    } else if (decoded is Map<String, dynamic>) {
      // Object containing nodes and optional edges lists
      final List<dynamic> rawNodes = decoded['nodes'] ?? [];
      final List<dynamic> rawEdges = decoded['edges'] ?? [];

      final List<Node> nodes = rawNodes.map((item) => Node.fromJson(item as Map<String, dynamic>)).toList();
      final List<Edge> edges = rawEdges.map((item) => Edge.fromJson(item as Map<String, dynamic>)).toList();

      return Graph.fromNodesList(nodes, edgeList: edges.isEmpty ? null : edges);
    } else {
      throw Exception('Invalid JSON structure in $assetPath');
    }
  }
}
