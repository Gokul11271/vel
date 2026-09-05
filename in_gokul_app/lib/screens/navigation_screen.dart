import 'package:flutter/material.dart';
import '../models/node.dart';
import '../algorithms/dijkstra.dart';
import '../theme/app_theme.dart';
import 'calibration_screen.dart';

class NavigationScreen extends StatelessWidget {
  final Node startNode;
  final Node targetNode;
  final DijkstraResult routeResult;
  final double? initialHeadingDegrees;

  const NavigationScreen({
    super.key,
    required this.startNode,
    required this.targetNode,
    required this.routeResult,
    this.initialHeadingDegrees,
  });

  @override
  Widget build(BuildContext context) {
    final path = routeResult.path;
    final bool hasPath = path.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.creamBg,
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
                        color: AppColors.textDark),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Route Preview',
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

            // ── Route summary card ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.primaryBlue,
                      AppColors.accentBlue,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.radio_button_checked_rounded,
                                  color: Colors.white70, size: 14),
                              const SizedBox(width: 8),
                              Text(startNode.name,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 13)),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.only(left: 6, top: 2, bottom: 2),
                            child: Icon(Icons.more_vert,
                                color: Colors.white30, size: 12),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.flag_rounded,
                                  color: Colors.white, size: 16),
                              const SizedBox(width: 8),
                              Text(targetNode.name,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
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
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${path.length} stops',
                            style: const TextStyle(
                                color: Colors.white,
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
                              color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
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
                  color: AppColors.textSubtle,
                  fontSize: 11,
                  letterSpacing: 1.2,
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
                              size: 56, color: AppColors.textSubtle),
                          SizedBox(height: 12),
                          Text('No path found',
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 15)),
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
                                          ? AppColors.primaryBlue
                                          : isLast
                                              ? AppColors.accentBlue
                                              : AppColors.softBlue,
                                      border: Border.all(
                                        color: isFirst || isLast
                                            ? AppColors.primaryBlue
                                            : AppColors.softBlueBorder,
                                        width: 2,
                                      ),
                                    ),
                                    child: Icon(
                                      isFirst
                                          ? Icons.play_arrow_rounded
                                          : isLast
                                              ? Icons.flag_rounded
                                              : Icons.circle,
                                      color: isFirst || isLast
                                          ? Colors.white
                                          : AppColors.primaryBlue,
                                      size: 13,
                                    ),
                                  ),
                                  if (!isLast)
                                    Container(
                                      width: 2,
                                      height: 50,
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 2),
                                      color: AppColors.creamBorder,
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Step card
                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: (isFirst || isLast)
                                      ? AppColors.softBlue
                                      : AppColors.creamSurface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: (isFirst || isLast)
                                        ? AppColors.softBlueBorder
                                        : AppColors.creamBorder,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
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
                                              color: (isFirst || isLast)
                                                  ? AppColors.primaryBlue
                                                  : AppColors.textDark,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '(${node.x.toStringAsFixed(1)}, ${node.y.toStringAsFixed(1)}, ${node.z.toStringAsFixed(1)})',
                                            style: const TextStyle(
                                                color: AppColors.textSubtle,
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
                                          color: AppColors.creamSurfaceAlt,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '${legDist.toStringAsFixed(1)} m',
                                          style: const TextStyle(
                                              color: AppColors.textMuted,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600),
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.explore_rounded, size: 20),
                label: const Text(
                  'Calibrate & Start AR Navigation',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      hasPath ? AppColors.primaryBlue : AppColors.creamSurfaceAlt,
                  foregroundColor: hasPath ? Colors.white : AppColors.textSubtle,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: hasPath ? 2 : 0,
                  shadowColor: AppColors.primaryBlue.withValues(alpha: 0.35),
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
                              initialHeadingDegrees: initialHeadingDegrees,
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
