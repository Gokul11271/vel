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
      backgroundColor: const Color(0xFF0A0D17),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── App bar ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Route Preview',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Route summary card ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      Colors.deepPurpleAccent.withValues(alpha: 0.25),
                      Colors.cyanAccent.withValues(alpha: 0.06),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                      color: Colors.deepPurpleAccent.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.circle,
                                  color: Colors.greenAccent, size: 10),
                              const SizedBox(width: 6),
                              Text(startNode.name,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.more_vert,
                                color: Colors.white12, size: 14),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.flag_rounded,
                                  color: Colors.cyanAccent, size: 12),
                              const SizedBox(width: 6),
                              Text(targetNode.name,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                Colors.cyanAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${path.length} stops',
                            style: const TextStyle(
                                color: Colors.cyanAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          hasPath
                              ? '${routeResult.totalDistance.toStringAsFixed(1)} m'
                              : 'No path',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text(
                'ROUTE STEPS',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // ── Steps list ─────────────────────────────────────────────────
            Expanded(
              child: !hasPath
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.route_rounded,
                              size: 56, color: Colors.white12),
                          SizedBox(height: 12),
                          Text('No path found',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 15)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: path.length,
                      itemBuilder: (context, index) {
                        final node = path[index];
                        final isFirst = index == 0;
                        final isLast = index == path.length - 1;

                        double legDist = 0;
                        if (index < path.length - 1) {
                          legDist = node.distanceTo(path[index + 1]);
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Timeline column
                            SizedBox(
                              width: 28,
                              child: Column(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isFirst
                                          ? Colors.greenAccent
                                          : isLast
                                              ? Colors.cyanAccent
                                              : Colors.deepPurpleAccent
                                                  .withValues(alpha: 0.5),
                                      border: isFirst || isLast
                                          ? Border.all(
                                              color: isFirst
                                                  ? Colors.greenAccent
                                                  : Colors.cyanAccent,
                                              width: 2)
                                          : null,
                                    ),
                                    child: Icon(
                                      isFirst
                                          ? Icons.play_arrow_rounded
                                          : isLast
                                              ? Icons.flag_rounded
                                              : Icons.circle,
                                      color: isFirst || isLast
                                          ? Colors.black
                                          : Colors.white70,
                                      size: 13,
                                    ),
                                  ),
                                  if (!isLast)
                                    Container(
                                      width: 2,
                                      height: 50,
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 2),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.white12,
                                            Colors.white.withValues(alpha: 0.04),
                                          ],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Step card
                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: (isFirst || isLast)
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : Colors.white.withValues(alpha: 0.03),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isFirst
                                        ? Colors.greenAccent
                                            .withValues(alpha: 0.25)
                                        : isLast
                                            ? Colors.cyanAccent
                                                .withValues(alpha: 0.25)
                                            : Colors.white.withValues(alpha: 0.06),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Step ${index + 1}: ${node.name}',
                                            style: TextStyle(
                                              color: isFirst
                                                  ? Colors.greenAccent
                                                  : isLast
                                                      ? Colors.cyanAccent
                                                      : Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '(${node.x.toStringAsFixed(1)}, ${node.y.toStringAsFixed(1)}, ${node.z.toStringAsFixed(1)})',
                                            style: const TextStyle(
                                                color: Colors.white30,
                                                fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!isLast)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.05),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '${legDist.toStringAsFixed(1)} m',
                                          style: const TextStyle(
                                              color: Colors.white38,
                                              fontSize: 11),
                                        ),
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

            // ── Start AR button ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.explore_rounded, size: 20),
                label: const Text(
                  'Calibrate & Start AR Navigation',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      hasPath ? Colors.cyanAccent : Colors.white12,
                  foregroundColor: hasPath ? Colors.black : Colors.white38,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: !hasPath
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CalibrationScreen(
                              startNode: startNode,
                              targetNode: targetNode,
                              routeResult: routeResult,
                            ),
                          ),
                        );
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
