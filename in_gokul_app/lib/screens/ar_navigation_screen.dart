import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../controllers/navigation_controller.dart';
import '../models/navigation_state.dart';
import '../models/pose.dart';
import '../models/node.dart';
import '../ar/ar_manager.dart';
import '../services/camera_service.dart';

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
  final CameraService _cameraService = CameraService();
  bool _arrivalDialogShown = false;
  bool _isCameraReady = false;

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

    _initCamera();
  }

  Future<void> _initCamera() async {
    if (_cameraService.isInitialized) {
      setState(() {
        _isCameraReady = true;
      });
    } else {
      final success = await _cameraService.initializeCamera();
      if (mounted) {
        setState(() {
          _isCameraReady = success;
        });
      }
    }
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
        backgroundColor: const Color(0xFF161B2B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.greenAccent, width: 2),
        ),
        title: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 36),
            SizedBox(width: 12),
            Text('Destination Reached!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You have successfully arrived at ${widget.targetNode.name}!',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.route, color: Colors.greenAccent),
                  const SizedBox(width: 8),
                  Text(
                    'Total steps: ${widget.controller.path.length}',
                    style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Exit AR view
            },
            child: const Text('Finish Navigation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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

  String _getTurnInstruction(double relBearingRad, double distToNext, String? nextNodeName) {
    if (distToNext <= 1.0) {
      return 'Approaching $nextNodeName';
    }
    final deg = relBearingRad * (180.0 / pi);
    if (deg.abs() < 20) {
      return 'Go straight forward (${distToNext.toStringAsFixed(1)}m)';
    } else if (deg < -20 && deg > -70) {
      return 'Bear slight left towards $nextNodeName';
    } else if (deg <= -70 && deg > -120) {
      return 'Turn left towards $nextNodeName';
    } else if (deg > 20 && deg < 70) {
      return 'Bear slight right towards $nextNodeName';
    } else if (deg >= 70 && deg < 120) {
      return 'Turn right towards $nextNodeName';
    } else {
      return 'Turn around towards $nextNodeName';
    }
  }

  IconData _getTurnIcon(double relBearingRad) {
    final deg = relBearingRad * (180.0 / pi);
    if (deg.abs() < 20) {
      return Icons.arrow_upward_rounded;
    } else if (deg < -20 && deg > -70) {
      return Icons.turn_slight_left_rounded;
    } else if (deg <= -70 && deg > -120) {
      return Icons.turn_left_rounded;
    } else if (deg > 20 && deg < 70) {
      return Icons.turn_slight_right_rounded;
    } else if (deg >= 70 && deg < 120) {
      return Icons.turn_right_rounded;
    } else {
      return Icons.u_turn_left_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.controller, widget.arManager]),
      builder: (context, _) {
        final trackingState = widget.controller.trackingState;
        final currentNode = widget.controller.currentNode;
        final nextNode = widget.controller.nextTargetNode;
        final distNext = widget.controller.distanceToNextTarget;
        final distTotal = widget.controller.totalDistanceRemaining;
        final arrow = widget.arManager.arrow;

        final isTrackingGood = trackingState == TrackingState.good;
        final isTrackingLost = trackingState == TrackingState.lost;
        final isFacingTarget = arrow.relativeBearingRadians.abs() < (20 * pi / 180.0);
        final turnInstruction = _getTurnInstruction(arrow.relativeBearingRadians, distNext, nextNode?.name);
        final turnIcon = _getTurnIcon(arrow.relativeBearingRadians);

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Live Camera Stream Background
              if (_isCameraReady && _cameraService.controller != null && _cameraService.controller!.value.isInitialized)
                SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _cameraService.controller!.value.previewSize?.height ?? MediaQuery.of(context).size.width,
                      height: _cameraService.controller!.value.previewSize?.width ?? MediaQuery.of(context).size.height,
                      child: CameraPreview(_cameraService.controller!),
                    ),
                  ),
                )
              else
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0A0D17), Color(0xFF161B2B)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.cyanAccent),
                  ),
                ),

              // 2. HUD Gradient Shading
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.75),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.85),
                    ],
                    stops: const [0.0, 0.22, 0.65, 1.0],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),

              // 3. Central 3D AR Navigation Arrow Visualizer
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dynamic rotating 3D directional arrow
                    Transform.rotate(
                      angle: arrow.relativeBearingRadians,
                      child: ScaleTransition(
                        scale: Tween(begin: 0.95, end: 1.08).animate(_pulseController),
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isFacingTarget
                                ? Colors.greenAccent.withValues(alpha: 0.25)
                                : arrow.color.withValues(alpha: 0.2),
                            border: Border.all(
                              color: isFacingTarget ? Colors.greenAccent : arrow.color,
                              width: 3.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (isFacingTarget ? Colors.greenAccent : arrow.color).withValues(alpha: 0.4),
                                blurRadius: 25,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.navigation_rounded,
                            size: 96,
                            color: isFacingTarget ? Colors.greenAccent : arrow.color,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Distance badge directly under AR arrow
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isFacingTarget ? Colors.greenAccent : Colors.cyanAccent.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isFacingTarget ? Icons.check_circle : Icons.straighten,
                            color: isFacingTarget ? Colors.greenAccent : Colors.cyanAccent,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${distNext.toStringAsFixed(1)} m to ${nextNode?.name ?? "Target"}',
                            style: TextStyle(
                              color: isFacingTarget ? Colors.greenAccent : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 4. Top Status Header & Waypoint Progress Bar
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Navigating to ${widget.targetNode.name}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Step ${widget.controller.currentStepIndex + 1} of ${widget.controller.path.length} • Total: ${distTotal.toStringAsFixed(1)}m remaining',
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          // Tracking Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isTrackingGood
                                  ? Colors.green.withValues(alpha: 0.25)
                                  : isTrackingLost
                                      ? Colors.red.withValues(alpha: 0.25)
                                      : Colors.amber.withValues(alpha: 0.25),
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
                                const SizedBox(width: 5),
                                Text(
                                  isTrackingGood ? 'LIVE' : isTrackingLost ? 'LOST' : 'LIMITED',
                                  style: TextStyle(
                                    color: isTrackingGood
                                        ? Colors.greenAccent
                                        : isTrackingLost
                                            ? Colors.redAccent
                                            : Colors.amberAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: widget.controller.path.isEmpty
                              ? 1.0
                              : (widget.controller.currentStepIndex + 1) / widget.controller.path.length,
                          backgroundColor: Colors.white12,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 5. Bottom Turn-by-Turn Card & Navigation Action Buttons
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Turn Guidance HUD Card
                        Card(
                          color: const Color(0xFF161B2B).withValues(alpha: 0.92),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: isFacingTarget ? Colors.greenAccent.withValues(alpha: 0.5) : Colors.cyanAccent.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: (isFacingTarget ? Colors.greenAccent : Colors.cyanAccent).withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    turnIcon,
                                    color: isFacingTarget ? Colors.greenAccent : Colors.cyanAccent,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        turnInstruction,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'From ${currentNode?.name ?? "Start"} ➔ ${nextNode?.name ?? "Destination"}',
                                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Quick Action Buttons (Step Forward / Next Waypoint)
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.directions_walk, size: 18),
                                label: const Text('+ Step Forward (0.8m)'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF232A42),
                                  foregroundColor: Colors.cyanAccent,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(color: Colors.cyanAccent, width: 1),
                                  ),
                                ),
                                onPressed: () {
                                  widget.controller.simulateStep(stepMeters: 0.8);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.skip_next, size: 18),
                              label: const Text('Next Node'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF232A42),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(color: Colors.white24, width: 1),
                                ),
                              ),
                              onPressed: () {
                                widget.controller.advanceToNextWaypoint();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
