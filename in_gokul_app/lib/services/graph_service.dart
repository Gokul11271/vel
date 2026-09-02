import '../models/graph.dart';
import '../models/node.dart';
import '../algorithms/dijkstra.dart';
import 'json_service.dart';

class GraphService {
  Graph? _graph;

  Graph? get graph => _graph;

  Future<Graph> init() async {
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
