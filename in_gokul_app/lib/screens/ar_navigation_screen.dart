import 'package:flutter/material.dart';
import '../controllers/navigation_controller.dart';
import '../models/navigation_state.dart';
import '../models/pose.dart';
import '../models/node.dart';
import '../ar/ar_manager.dart';

class ArNavigationScreen extends StatefulWidget {
  final NavigationController controller;
  final ARManager arManager;
  final Node startNode;
  final Node targetNode;

  const ArNavigationScreen({
    super.key,
    required this.controller,
    required this.arManager,
    required this.startNode,
    required this.targetNode,
  });

  @override
  State<ArNavigationScreen> createState() => _ArNavigationScreenState();
}

class _ArNavigationScreenState extends State<ArNavigationScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _arrivalDialogShown = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    widget.controller.addListener(_onControllerUpdated);
    widget.arManager.initializeSession();
    widget.arManager.setTargetNode(widget.controller.nextTargetNode);
  }

  void _onControllerUpdated() {
    // Synchronize ARManager with active target node
    widget.arManager.setTargetNode(widget.controller.nextTargetNode);

    if (widget.controller.state == NavigationState.destinationReached && !_arrivalDialogShown) {
      _arrivalDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showArrivalDialog();
        }
      });
    }
  }

  void _showArrivalDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2337),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 32),
            SizedBox(width: 10),
            Text('Destination Reached!', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'You have arrived at ${widget.targetNode.name}!',
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Exit AR view
            },
            child: const Text('Finish Navigation', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdated);
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.controller, widget.arManager]),
      builder: (context, _) {
        final state = widget.controller.state;
        final trackingState = widget.controller.trackingState;
        final currentNode = widget.controller.currentNode;
        final nextNode = widget.controller.nextTargetNode;
        final distNext = widget.controller.distanceToNextTarget;
        final distTotal = widget.controller.totalDistanceRemaining;
        final arrow = widget.arManager.arrow;
        final latestPose = widget.controller.latestPose;

        final isTrackingGood = trackingState == TrackingState.good;
        final isTrackingLost = trackingState == TrackingState.lost;

        return Scaffold(
          body: Stack(
            children: [
              // AR Camera Feed / Spatial Viewport
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0D111A), Color(0xFF1A1F30)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Tracking State Watermark
                      Text(
                        state.displayTitle.toUpperCase(),
                        style: TextStyle(
                          color: isTrackingLost ? Colors.redAccent : Colors.cyanAccent.withValues(alpha: 0.7),
                          letterSpacing: 3,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 30),

                      // 3D Directional AR Arrow Visualizer
                      Transform.rotate(
                        angle: arrow.relativeBearingRadians,
                        child: ScaleTransition(
                          scale: Tween(begin: 0.95, end: 1.1).animate(_pulseController),
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: arrow.color.withValues(alpha: 0.25),
                              border: Border.all(color: arrow.color, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: arrow.color.withValues(alpha: 0.35),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.navigation_rounded,
                              size: 90,
                              color: arrow.color,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (nextNode != null)
                        Text(
                          'Follow arrow towards ${nextNode.name}',
                          style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                    ],
                  ),
                ),
              ),

              // Top HUD Overlay
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: Text(
                              'AR Navigation ➔ ${widget.targetNode.name}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Tracking Badge (Change #9)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isTrackingGood
                                  ? Colors.green.withValues(alpha: 0.2)
                                  : isTrackingLost
                                      ? Colors.red.withValues(alpha: 0.2)
                                      : Colors.amber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isTrackingGood
                                    ? Colors.greenAccent
                                    : isTrackingLost
                                        ? Colors.redAccent
                                        : Colors.amberAccent,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isTrackingGood ? Icons.circle : Icons.warning_amber_rounded,
                                  color: isTrackingGood
                                      ? Colors.greenAccent
                                      : isTrackingLost
                                          ? Colors.redAccent
                                          : Colors.amberAccent,
                                  size: 10,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isTrackingGood ? 'GOOD' : isTrackingLost ? 'LOST' : 'LIMITED',
                                  style: TextStyle(
                                    color: isTrackingGood
                                        ? Colors.greenAccent
                                        : isTrackingLost
                                            ? Colors.redAccent
                                            : Colors.amberAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Navigation Status HUD Card
                      Card(
                        color: Colors.black.withValues(alpha: 0.8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('CURRENT WAYPOINT', style: TextStyle(color: Colors.grey, fontSize: 10)),
                                      Text(
                                        currentNode?.name ?? 'Start',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                    ],
                                  ),
                                  const Icon(Icons.arrow_forward_rounded, color: Colors.cyanAccent),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text('NEXT WAYPOINT', style: TextStyle(color: Colors.grey, fontSize: 10)),
                                      Text(
                                        nextNode?.name ?? 'Destination',
                                        style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(color: Colors.white24, height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  Column(
                                    children: [
                                      const Text('Next Waypoint', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                      Text(
                                        '${distNext.toStringAsFixed(1)} m',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    children: [
                                      const Text('Total Remaining', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                      Text(
                                        '${distTotal.toStringAsFixed(1)} m',
                                        style: const TextStyle(color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold, fontSize: 18),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Tracking HUD & Dev Step Controls
              Positioned(
                bottom: 24,
                left: 16,
                right: 16,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        'AR Pos: (${latestPose.position.x.toStringAsFixed(2)}, ${latestPose.position.y.toStringAsFixed(2)}, ${latestPose.position.z.toStringAsFixed(2)}) • Yaw: ${latestPose.yawDegrees.toStringAsFixed(1)}°',
                        style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Test step simulation button for emulators
                    ElevatedButton.icon(
                      icon: const Icon(Icons.directions_walk, size: 20),
                      label: const Text('Simulate Movement Step (Dev / Emulation)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white12,
                        foregroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: widget.controller.isFinished ? null : () => widget.controller.simulateStep(stepMeters: 0.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
