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
    final destinations = graphService
        .getDestinations()
        .where((n) => n.id != startNode.id)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0D17),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top bar ────────────────────────────────────────────────────
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
                      'Choose Destination',
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

            // ── Origin chip ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.cyanAccent.withValues(alpha: 0.08),
                  border:
                      Border.all(color: Colors.cyanAccent.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.my_location,
                        color: Colors.cyanAccent, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'From: ${startNode.name}  (#${startNode.id})',
                      style: const TextStyle(
                        color: Colors.cyanAccent,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Padding(
              padding: EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: Text(
                'WHERE DO YOU WANT TO GO?',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // ── Destination list ───────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: destinations.length,
                itemBuilder: (context, index) {
                  final node = destinations[index];
                  final dist = startNode.distanceTo(node);

                  return _DestinationTile(
                    node: node,
                    directDistance: dist,
                    onTap: () {
                      final routeResult =
                          graphService.findRoute(startNode.id, node.id);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NavigationScreen(
                            startNode: startNode,
                            targetNode: node,
                            routeResult: routeResult,
                          ),
                        ),
                      );
                    },
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

class _DestinationTile extends StatefulWidget {
  final Node node;
  final double directDistance;
  final VoidCallback onTap;

  const _DestinationTile({
    required this.node,
    required this.directDistance,
    required this.onTap,
  });

  @override
  State<_DestinationTile> createState() => _DestinationTileState();
}

class _DestinationTileState extends State<_DestinationTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: _pressed
              ? Colors.cyanAccent.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: _pressed
                ? Colors.cyanAccent.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.07),
          ),
        ),
        child: Row(
          children: [
            // Node badge
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.deepPurpleAccent.withValues(alpha: 0.2),
                border: Border.all(
                    color: Colors.deepPurpleAccent.withValues(alpha: 0.6)),
              ),
              child: Center(
                child: Text(
                  '#${widget.node.id}',
                  style: const TextStyle(
                    color: Colors.deepPurpleAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.node.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${widget.directDistance.toStringAsFixed(2)} m straight-line distance',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 16, color: Colors.white30),
          ],
        ),
      ),
    );
  }
}
