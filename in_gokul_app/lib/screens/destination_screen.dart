import 'package:flutter/material.dart';
import '../services/graph_service.dart';
import '../models/node.dart';
import '../theme/app_theme.dart';
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
      backgroundColor: AppColors.creamBg,
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
                        color: AppColors.textDark),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Choose Destination',
                      style: TextStyle(
                        color: AppColors.textDark,
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
                  color: AppColors.softBlue,
                  border:
                      Border.all(color: AppColors.softBlueBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.my_location,
                        color: AppColors.primaryBlue, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'From: ${startNode.name}  (#${startNode.id})',
                      style: const TextStyle(
                        color: AppColors.primaryBlue,
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
                  color: AppColors.textSubtle,
                  fontSize: 11,
                  letterSpacing: 1.2,
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
              ? AppColors.softBlue
              : AppColors.creamSurface,
          border: Border.all(
            color: _pressed
                ? AppColors.primaryBlue
                : AppColors.creamBorder,
            width: _pressed ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Node badge
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.softBlue,
                border: Border.all(
                    color: AppColors.softBlueBorder),
              ),
              child: Center(
                child: Text(
                  '#${widget.node.id}',
                  style: const TextStyle(
                    color: AppColors.primaryBlue,
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
                      color: AppColors.textDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${widget.directDistance.toStringAsFixed(2)} m straight-line distance',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 16, color: AppColors.primaryBlue),
          ],
        ),
      ),
    );
  }
}
