import '../models/graph.dart';
import '../models/node.dart';
import '../algorithms/dijkstra.dart';
import 'json_service.dart';

class GraphService {
  Graph? _graph;

  Graph? get graph => _graph;

  /// Initialises the graph.
  /// Priority: 1) Device-saved map from Mapper  2) Bundled asset fallback.
  Future<Graph> init() async {
    // Try loading the mapper's saved map first (same-device mapping → navigation)
    final savedMap = await JsonService.loadSavedMap();
    if (savedMap != null && savedMap.nodes.length >= 2) {
      _graph = savedMap.toGraph();
      return _graph!;
    }

    // Fallback to bundled asset
    _graph = await JsonService.loadNavigationGraph();
    return _graph!;
  }

  List<Node> getDestinations() {
    if (_graph == null) return [];
    return _graph!.nodes.values.toList();
  }

  DijkstraResult findRoute(int startId, int targetId) {
    if (_graph == null) {
      return DijkstraResult(path: [], totalDistance: double.infinity);
    }
    return Dijkstra.findShortestPath(_graph!, startId, targetId);
  }
}
