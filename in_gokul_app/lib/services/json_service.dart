import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/node.dart';
import '../models/edge.dart';
import '../models/graph.dart';
import '../models/building_map.dart';

class JsonService {
  /// Loads navigation data from assets/navigation.json (or a custom asset path).
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

  // ── Mapper: save / load from device documents ─────────────────────────────

  /// Saves a [BuildingMap] to `<documents>/navigation.json` on device storage.
  /// Returns the [File] that was written so the caller can share it.
  static Future<File> saveNavigationJson(BuildingMap map) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/navigation.json');
    final jsonString = const JsonEncoder.withIndent('  ').convert(map.toJson());
    await file.writeAsString(jsonString, flush: true);
    return file;
  }

  /// Loads a [BuildingMap] from `<documents>/navigation.json` if it exists.
  /// Returns null if no saved map is present.
  static Future<BuildingMap?> loadSavedMap() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/navigation.json');
      if (!await file.exists()) return null;
      final jsonString = await file.readAsString();
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      return BuildingMap.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }
}
