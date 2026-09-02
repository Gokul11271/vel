import 'package:flutter/material.dart';
import '../services/graph_service.dart';
import '../models/node.dart';
import 'navigation_screen.dart';

class DestinationScreen extends StatelessWidget {
  final GraphService graphService;
  final Node startNode;

  const DestinationScreen({
    super.key,
    required this.graphService,
    required this.startNode,
  });

  @override
  Widget build(BuildContext context) {
    final destinations = graphService.getDestinations().where((n) => n.id != startNode.id).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Destination'),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.deepPurple.shade50,
            child: Row(
              children: [
                const Icon(Icons.my_location, color: Colors.deepPurple),
                const SizedBox(width: 12),
                Text(
                  'Starting from: ${startNode.name} (Node #${startNode.id})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: destinations.length,
              itemBuilder: (context, index) {
                final node = destinations[index];
                final dist = startNode.distanceTo(node);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: Colors.deepPurple.shade100,
                      child: Text(
                        '#${node.id}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple),
                      ),
                    ),
                    title: Text(
                      node.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: Text(
                      '3D Pos: (${node.x}, ${node.y}, ${node.z}) • Direct Dist: ${dist.toStringAsFixed(2)}m',
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                    onTap: () {
                      final routeResult = graphService.findRoute(startNode.id, node.id);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NavigationScreen(
                            startNode: startNode,
                            targetNode: node,
                            routeResult: routeResult,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
