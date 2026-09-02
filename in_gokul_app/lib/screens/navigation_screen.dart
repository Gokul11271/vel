import 'package:flutter/material.dart';
import '../models/node.dart';
import '../algorithms/dijkstra.dart';
import 'calibration_screen.dart';

class NavigationScreen extends StatelessWidget {
  final Node startNode;
  final Node targetNode;
  final DijkstraResult routeResult;

  const NavigationScreen({
    super.key,
    required this.startNode,
    required this.targetNode,
    required this.routeResult,
  });

  @override
  Widget build(BuildContext context) {
    final path = routeResult.path;
    final bool hasPath = path.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text('Route to ${targetNode.name}'),
      ),
      body: Column(
        children: [
          // Header Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: Colors.deepPurple,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${startNode.name} ➔ ${targetNode.name}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${path.length} Steps',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  hasPath
                      ? 'Total Route Distance: ${routeResult.totalDistance.toStringAsFixed(2)} meters'
                      : 'No valid path found between selected nodes',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          // Route Steps List
          Expanded(
            child: !hasPath
                ? const Center(
                    child: Text('No path calculated'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: path.length,
                    itemBuilder: (context, index) {
                      final node = path[index];
                      final isFirst = index == 0;
                      final isLast = index == path.length - 1;

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Timeline indicator
                          Column(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isFirst
                                      ? Colors.green
                                      : isLast
                                          ? Colors.red
                                          : Colors.deepPurple,
                                ),
                                child: Icon(
                                  isFirst
                                      ? Icons.play_arrow
                                      : isLast
                                          ? Icons.flag
                                          : Icons.circle,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                              if (!isLast)
                                Container(
                                  width: 2,
                                  height: 50,
                                  color: Colors.grey.shade300,
                                ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          // Step Details
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isFirst || isLast ? Colors.deepPurple.shade200 : Colors.transparent,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Step ${index + 1}: ${node.name}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        'Node #${node.id}',
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Coordinates: (${node.x}, ${node.y}, ${node.z})',
                                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton.icon(
          icon: const Icon(Icons.explore_rounded),
          label: const Text('Calibrate & Start AR Navigation', style: TextStyle(fontSize: 16)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: !hasPath
              ? null
              : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CalibrationScreen(
                        startNode: startNode,
                        targetNode: targetNode,
                        routeResult: routeResult,
                      ),
                    ),
                  );
                },
        ),
      ),
    );
  }
}
