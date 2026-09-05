import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../controllers/navigation_controller.dart';
import '../models/navigation_state.dart';
import '../models/pose.dart';
import '../models/node.dart';
import '../ar/ar_manager.dart';
import '../ar/ar_path_painter.dart';
import '../services/camera_service.dart';
import '../tracking/native_ar_position_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/debug_overlay.dart';
import '../widgets/fps_counter.dart';
import '../widgets/waypoint_marker.dart';
import 'success_screen.dart';

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

class _ArNavigationScreenState extends State<ArNavigationScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _pulseController;
  late AnimationController _flashController;
  final CameraService _cameraService = CameraService();
  final FpsCounter _fpsCounter = FpsCounter();

  bool _destinationNavigated = false;
  bool _isCameraReady = false;
  bool _showDebug = kDebugMode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    widget.controller.addListener(_onControllerUpdated);
    widget.arManager.initializeSession();
    widget.arManager.setTargetNode(widget.controller.nextTargetNode);

    _initCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _cameraService.initializeCamera(force: true).then((ready) {
        if (mounted) setState(() => _isCameraReady = ready);
      });
    }
  }

  Future<void> _initCamera() async {
    final success = _cameraService.isInitialized
        ? true
        : await _cameraService.initializeCamera();
    if (mounted) setState(() => _isCameraReady = success);
  }

  Future<void> _forceRestartCamera() async {
    setState(() => _isCameraReady = false);
    final success = await _cameraService.restartCamera();
    if (mounted) setState(() => _isCameraReady = success);
  }

  void _realignForward() {
    widget.controller.completeCalibration();
    widget.arManager.setTargetNode(widget.controller.nextTargetNode);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎯 Forward direction calibrated to your view!'),
        backgroundColor: AppColors.primaryBlue,
        duration: Duration(milliseconds: 900),
      ),
    );
  }

  void _onControllerUpdated() {
    widget.arManager.setTargetNode(widget.controller.nextTargetNode);

    if (widget.controller.state == NavigationState.waypointReached) {
      _flashController.forward(from: 0.0);
    }

    if (widget.controller.state == NavigationState.destinationReached &&
        !_destinationNavigated) {
      _destinationNavigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _navigateToSuccess();
      });
    }
  }

  void _navigateToSuccess() {
    int steps = 0;
    if (widget.controller.positionProvider is NativeArPositionProvider) {
      steps = (widget.controller.positionProvider as NativeArPositionProvider)
          .totalSteps;
    }
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (ctx, anim, secondAnim) => SuccessScreen(
          destination: widget.targetNode,
          totalWaypoints: widget.controller.path.length,
          totalDistance: _totalPathDist(),
          totalSteps: steps,
        ),
        transitionsBuilder: (ctx, anim, secondAnim, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 700),
      ),
    );
  }

  double _totalPathDist() {
    double d = 0;
    for (int i = 0; i < widget.controller.path.length - 1; i++) {
      d += widget.controller.path[i].distanceTo(widget.controller.path[i + 1]);
    }
    return d;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_onControllerUpdated);
    _pulseController.dispose();
    _flashController.dispose();
    widget.controller.dispose();
    widget.arManager.dispose();
    widget.controller.positionProvider.dispose();
    super.dispose();
  }

  // ─── Turn helpers ──────────────────────────────────────────────────────────

  String _getTurnInstruction(double bearRad, double dist, String? name) {
    if (dist <= 1.2) return '✓  Arriving at ${name ?? "waypoint"}';
    final deg = bearRad * (180 / pi);
    if (deg.abs() < 18) return 'Go straight  (${dist.toStringAsFixed(1)} m)';
    if (deg < -18 && deg > -65) return 'Bear left toward ${name ?? "target"}';
    if (deg <= -65 && deg > -125) return 'Turn left toward ${name ?? "target"}';
    if (deg > 18 && deg < 65) return 'Bear right toward ${name ?? "target"}';
    if (deg >= 65 && deg < 125) return 'Turn right toward ${name ?? "target"}';
    return 'Turn around  —  ${name ?? "target"} is behind you';
  }

  IconData _getTurnIcon(double bearRad) {
    final deg = bearRad * (180 / pi);
    if (deg.abs() < 18) return Icons.arrow_upward_rounded;
    if (deg < -18 && deg > -65) return Icons.turn_slight_left_rounded;
    if (deg <= -65 && deg > -125) return Icons.turn_left_rounded;
    if (deg > 18 && deg < 65) return Icons.turn_slight_right_rounded;
    if (deg >= 65 && deg < 125) return Icons.turn_right_rounded;
    return Icons.u_turn_left_rounded;
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    _fpsCounter.onFrame();
    final size = MediaQuery.of(context).size;

    return ListenableBuilder(
      listenable: Listenable.merge([widget.controller, widget.arManager]),
      builder: (context, _) {
        final trackingState = widget.controller.trackingState;
        final currentNode = widget.controller.currentNode;
        final nextNode = widget.controller.nextTargetNode;
        final distNext = widget.controller.distanceToNextTarget;
        final distTotal = widget.controller.totalDistanceRemaining;
        final arrow = widget.arManager.arrow;
        final userPose = widget.controller.latestPose;

        int stepCount = 0;
        if (widget.controller.positionProvider is NativeArPositionProvider) {
          stepCount = (widget.controller.positionProvider
                  as NativeArPositionProvider)
              .totalSteps;
        }

        final isTrackingGood = trackingState == TrackingState.good;
        final isTrackingLost = trackingState == TrackingState.lost;
        final bearRad = arrow.relativeBearingRadians;
        final isFacingTarget = bearRad.abs() < (20 * pi / 180);
        final isTurningAround = bearRad.abs() > (130 * pi / 180);
        final arrowColor = isFacingTarget
            ? AppColors.lightBlue
            : isTurningAround
                ? AppColors.warning
                : AppColors.accentBlue;

        final totalNodes = widget.controller.path.length;
        final progress = totalNodes < 2
            ? 1.0
            : (widget.controller.currentStepIndex + 1) / totalNodes;

        final turnInstruction =
            _getTurnInstruction(bearRad, distNext, nextNode?.name);
        final turnIcon = _getTurnIcon(bearRad);

        // ── Floating sign screen position ──────────────────────────────────
        // The sign slides LEFT/RIGHT based on bearing — looks like it's
        // physically placed in the corridor ahead of the user.
        final signHorizOffset = sin(bearRad) * size.width * 0.32;
        final signX = (size.width / 2 + signHorizOffset - 55)
            .clamp(8.0, size.width - 118.0);
        const signY = 0.27; // 27% from top — corridor sign height

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // ── 1. Live Camera ───────────────────────────────────────────
              if (_isCameraReady &&
                  _cameraService.controller != null &&
                  _cameraService.controller!.value.isInitialized)
                SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _cameraService.controller!.value.previewSize
                              ?.height ??
                          size.width,
                      height: _cameraService.controller!.value.previewSize
                              ?.width ??
                          size.height,
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
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: Colors.cyanAccent),
                        const SizedBox(height: 14),
                        const Text('Initializing camera…',
                            style: TextStyle(color: Colors.white54)),
                        if (!_isCameraReady) ...[
                          const SizedBox(height: 12),
                          TextButton.icon(
                            icon: const Icon(Icons.refresh,
                                color: Colors.cyanAccent),
                            label: const Text('Retry',
                                style: TextStyle(color: Colors.cyanAccent)),
                            onPressed: _initCamera,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

              // ── 2. Vignette gradient ──────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.72),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.88),
                    ],
                    stops: const [0.0, 0.20, 0.60, 1.0],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),

              // ── 3. AR FLOOR PATH (CustomPaint) ────────────────────────────
              // This draws the perspective path, chevron, and progress dots
              // that look like they are painted ON THE FLOOR.
              CustomPaint(
                size: Size.infinite,
                painter: ARPathPainter(
                  relativeBearing: bearRad,
                  distanceToNext: distNext,
                  isFacingTarget: isFacingTarget,
                  isTurningAround: isTurningAround,
                  primaryColor: arrowColor,
                ),
              ),

              // ── 4. Waypoint-reached blue flash ───────────────────────────
              AnimatedBuilder(
                animation: _flashController,
                builder: (ctx, child) {
                  final t = _flashController.value;
                  final opacity = t < 0.3
                      ? t / 0.3
                      : t < 0.7
                          ? 1.0
                          : (1.0 - t) / 0.3;
                  if (t == 0) return const SizedBox.shrink();
                  return Container(
                    color: AppColors.lightBlue.withValues(alpha: opacity * 0.22),
                  );
                },
              ),

              // ── 5. FLOATING CORRIDOR SIGN (bearing-offset arrow) ──────────
              // This is the key AR trick: the sign slides LEFT/RIGHT on screen
              // based on which direction you need to turn, making it appear
              // as though it's positioned IN the corridor ahead of you.
              Positioned(
                left: signX,
                top: size.height * signY,
                child: Column(
                  children: [
                    // Glassmorphic sign card
                    ScaleTransition(
                      scale: Tween(begin: 0.97, end: 1.04)
                          .animate(_pulseController),
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          color: arrowColor.withValues(alpha: 0.16),
                          border: Border.all(
                            color: arrowColor.withValues(alpha: 0.8),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: arrowColor.withValues(alpha: 0.40),
                              blurRadius: 30,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          turnIcon,
                          size: 60,
                          color: arrowColor,
                        ),
                      ),
                    ),

                    const SizedBox(height: 7),

                    // Distance badge below sign
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: arrowColor.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isFacingTarget
                                ? Icons.check_circle_outline
                                : Icons.straighten,
                            color: arrowColor,
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${distNext.toStringAsFixed(1)} m',
                            style: TextStyle(
                              color: arrowColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── 6. Top Header Bar ─────────────────────────────────────────
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12.0, vertical: 6.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new,
                                color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'To: ${widget.targetNode.name}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Step ${widget.controller.currentStepIndex + 1}/$totalNodes  •  ${distTotal.toStringAsFixed(1)} m left',
                                  style: const TextStyle(
                                      color: Colors.white60, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          _TrackingBadge(
                              isGood: isTrackingGood, isLost: isTrackingLost),
                          const SizedBox(width: 4),
                          // Re-align button
                          GestureDetector(
                            onTap: _realignForward,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue
                                    .withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: AppColors.lightBlue
                                        .withValues(alpha: 0.6)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.gps_fixed,
                                      size: 14, color: AppColors.lightBlue),
                                  SizedBox(width: 4),
                                  Text(
                                    'Re-align',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Refresh Camera button
                          GestureDetector(
                            onTap: _forceRestartCamera,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: const Icon(
                                Icons.refresh_rounded,
                                size: 16,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _showDebug = !_showDebug),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _showDebug
                                    ? Colors.amberAccent.withValues(alpha: 0.2)
                                    : Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: _showDebug
                                        ? Colors.amberAccent
                                        : Colors.white24),
                              ),
                              child: Icon(
                                Icons.bug_report_rounded,
                                size: 16,
                                color: _showDebug
                                    ? Colors.amberAccent
                                    : Colors.white38,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white10,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(arrowColor),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── 7. Bottom Turn Card ───────────────────────────────────────
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Card(
                      color: AppColors.navyDark.withValues(alpha: 0.94),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(
                          color: arrowColor.withValues(alpha: 0.45),
                          width: 1.5,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: arrowColor.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(turnIcon,
                                  color: arrowColor, size: 28),
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
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${currentNode?.name ?? "Start"} → ${nextNode?.name ?? "Destination"}',
                                    style: const TextStyle(
                                        color: Colors.white54, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            // Live coordinate mini-pill
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${(userPose.yawDegrees + 360) % 360 ~/ 1}°',
                                  style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 10,
                                      fontFamily: 'monospace'),
                                ),
                                Text(
                                  '$stepCount steps',
                                  style: const TextStyle(
                                      color: Colors.white30,
                                      fontSize: 10,
                                      fontFamily: 'monospace'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── 8. Waypoint Marker (shown within 8 m of next node) ────────
              if (nextNode != null &&
                  widget.controller.state != NavigationState.destinationReached)
                Positioned(
                  top: size.height * 0.52,
                  left: 0,
                  right: 0,
                  child: WaypointMarker(
                    nodeName: nextNode.name,
                    distanceToNode: distNext,
                    waypointReached:
                        widget.controller.state == NavigationState.waypointReached,
                  ),
                ),

              // ── 9. Destination Glow (within 5 m of final destination) ─────
              if (widget.controller.finalDestination != null &&
                  distTotal <= 5.0 &&
                  widget.controller.state != NavigationState.destinationReached)
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (ctx, _) {
                    final pulse = _pulseController.value;
                    return Center(
                      child: Opacity(
                        opacity: 0.6 + pulse * 0.4,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 90 + pulse * 20,
                              height: 90 + pulse * 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.lightBlue
                                    .withValues(alpha: 0.10 + pulse * 0.10),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryBlue
                                        .withValues(alpha: 0.4 + pulse * 0.25),
                                    blurRadius: 40 + pulse * 20,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.place_rounded,
                                color: AppColors.lightBlue,
                                size: 48,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '🎉  ${widget.targetNode.name}',
                              style: TextStyle(
                                color: AppColors.lightBlue
                                    .withValues(alpha: 0.85 + pulse * 0.15),
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              '${distTotal.toStringAsFixed(1)} m away',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

              // ── 10. Debug Overlay ─────────────────────────────────────────
              if (_showDebug)
                DebugOverlay(
                  trackingState: trackingState,
                  currentNode: currentNode,
                  nextNode: nextNode,
                  distanceToNext: distNext,
                  userPose: userPose,
                  fpsCounter: _fpsCounter,
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Tracking Badge ────────────────────────────────────────────────────────────

class _TrackingBadge extends StatelessWidget {
  final bool isGood;
  final bool isLost;
  const _TrackingBadge({required this.isGood, required this.isLost});

  @override
  Widget build(BuildContext context) {
    final color = isGood
        ? Colors.greenAccent
        : isLost
            ? Colors.redAccent
            : Colors.amberAccent;
    final label = isGood ? 'LIVE' : isLost ? 'LOST' : 'LIMITED';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isGood ? Icons.circle : Icons.warning_amber_rounded,
            color: color,
            size: 8,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
