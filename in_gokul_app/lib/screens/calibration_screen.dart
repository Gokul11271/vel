import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../controllers/navigation_controller.dart';
import '../models/pose.dart';
import '../models/node.dart';
import '../algorithms/dijkstra.dart';
import '../services/world_alignment_service.dart';
import '../services/camera_service.dart';
import '../tracking/native_ar_position_provider.dart';
import '../theme/app_theme.dart';
import '../ar/ar_manager.dart';
import '../widgets/compass_calibration_dialog.dart';
import 'ar_navigation_screen.dart';

class CalibrationScreen extends StatefulWidget {
  final Node startNode;
  final Node targetNode;
  final DijkstraResult routeResult;

  const CalibrationScreen({
    super.key,
    required this.startNode,
    required this.targetNode,
    required this.routeResult,
  });

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> with SingleTickerProviderStateMixin {
  late NavigationController _controller;
  late WorldAlignmentService _alignmentService;
  late NativeArPositionProvider _positionProvider;
  late ARManager _arManager;
  late AnimationController _pulseController;
  final CameraService _cameraService = CameraService();
  StreamSubscription<bool>? _anomalySubscription;
  bool _isCalibrationSheetOpen = false;
  bool _isCalibrating = false;
  bool _isCameraReady = false;

  @override
  void initState() {
    super.initState();
    _alignmentService = WorldAlignmentService();
    _positionProvider = NativeArPositionProvider();
    _controller = NavigationController(
      routeResult: widget.routeResult,
      positionProvider: _positionProvider,
      alignmentService: _alignmentService,
    );
    _arManager = ARManager(
      positionProvider: _positionProvider,
      alignmentService: _alignmentService,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _positionProvider.start();
    _controller.beginCalibration();

    _anomalySubscription = _positionProvider.onMagneticAnomaly.listen((isAnomaly) {
      if (isAnomaly && mounted && !_isCalibrationSheetOpen && !_navigatedToAr) {
        _showFigure8CalibrationGuide(isAutoTriggered: true);
      }
    });

    _setupCamera();
  }

  void _showFigure8CalibrationGuide({bool isAutoTriggered = false}) {
    if (_isCalibrationSheetOpen) return;
    _isCalibrationSheetOpen = true;
    CompassCalibrationSheet.show(
      context,
      onDismissed: () {
        _isCalibrationSheetOpen = false;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✨ Compass calibrated! Point forward and tap Align & Start.'),
              backgroundColor: AppColors.primaryBlue,
              duration: Duration(milliseconds: 1200),
            ),
          );
        }
      },
    );
  }

  Future<void> _setupCamera() async {
    final success = await _cameraService.initializeCamera();
    if (mounted) {
      setState(() {
        _isCameraReady = success;
      });
    }
  }

  bool _navigatedToAr = false;

  @override
  void dispose() {
    _anomalySubscription?.cancel();
    _pulseController.dispose();
    if (!_navigatedToAr) {
      _controller.dispose();
      _positionProvider.dispose();
      _arManager.dispose();
    }
    super.dispose();
  }

  void _onCalibratePressed() {
    setState(() {
      _isCalibrating = true;
    });

    // Execute alignment
    _controller.completeCalibration();
    _arManager.setTargetNode(_controller.nextTargetNode);

    _navigatedToAr = true;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ World Alignment Calibrated Successfully!'),
        backgroundColor: AppColors.primaryBlue,
        duration: Duration(milliseconds: 900),
      ),
    );

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ArNavigationScreen(
            controller: _controller,
            arManager: _arManager,
            startNode: widget.startNode,
            targetNode: widget.targetNode,
          ),
        ),
      );
    });
  }

  String _getHeadingDirection(double deg) {
    if (deg >= 337.5 || deg < 22.5) return 'N';
    if (deg >= 22.5 && deg < 67.5) return 'NE';
    if (deg >= 67.5 && deg < 112.5) return 'E';
    if (deg >= 112.5 && deg < 157.5) return 'SE';
    if (deg >= 157.5 && deg < 202.5) return 'S';
    if (deg >= 202.5 && deg < 247.5) return 'SW';
    if (deg >= 247.5 && deg < 292.5) return 'W';
    return 'NW';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final trackingState = _controller.trackingState;
        final isTrackingGood = trackingState == TrackingState.good;
        final headingDeg = (_controller.latestPose.yawDegrees + 360) % 360;
        final headingDir = _getHeadingDirection(headingDeg);

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Live Camera Feed Viewport
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
                      colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 56),
                        const SizedBox(height: 16),
                        Text(
                          _cameraService.errorMessage ?? 'Initializing Camera Feed...',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        if (!_isCameraReady) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry Camera Access'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentBlue,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _setupCamera,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

              // 2. Dark HUD Gradient Vignette Overlays
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.72),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.88),
                    ],
                    stops: const [0.0, 0.2, 0.65, 1.0],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),

              // 3. Central AR Calibration Crosshair / Reticle
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Pulsing outer circle
                        ScaleTransition(
                          scale: Tween(begin: 0.9, end: 1.15).animate(_pulseController),
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.lightBlue.withValues(alpha: 0.4), width: 2),
                            ),
                          ),
                        ),
                        // Reticle Glass Ring
                        Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.lightBlue, width: 2.5),
                            color: AppColors.primaryBlue.withValues(alpha: 0.15),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accentBlue.withValues(alpha: 0.3),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                        ),
                        // Center Calibration Icon
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.explore_rounded,
                              size: 56,
                              color: AppColors.lightBlue,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${headingDeg.toStringAsFixed(0)}° $headingDir',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.navyDark.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.lightBlue.withValues(alpha: 0.6)),
                      ),
                      child: const Text(
                        'ALIGN CAMERA DOWN CORRIDOR',
                        style: TextStyle(
                          color: AppColors.lightBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 4. Top App Bar & Badges
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
                          const Expanded(
                            child: Text(
                              'AR World Calibration',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          // Tracking Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isTrackingGood
                                  ? AppColors.primaryBlue.withValues(alpha: 0.3)
                                  : Colors.amber.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isTrackingGood ? AppColors.lightBlue : Colors.amberAccent,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isTrackingGood ? Icons.sensors : Icons.sensors_off,
                                  color: isTrackingGood ? AppColors.lightBlue : Colors.amberAccent,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  trackingState.label,
                                  style: TextStyle(
                                    color: isTrackingGood ? Colors.white : Colors.amberAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Figure-8 Calibration button
                          GestureDetector(
                            onTap: () => _showFigure8CalibrationGuide(isAutoTriggered: false),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.6)),
                              ),
                              child: const Icon(
                                Icons.screen_rotation_alt_rounded,
                                size: 16,
                                color: Colors.amberAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 5. Bottom Instructions & Action Panel
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.92),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: BorderSide(color: AppColors.lightBlue.withValues(alpha: 0.3), width: 1.5),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.pin_drop, color: AppColors.lightBlue, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Start: ${widget.startNode.name}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryBlue.withValues(alpha: 0.35),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppColors.lightBlue.withValues(alpha: 0.5)),
                                      ),
                                      child: Text(
                                        'Node #${widget.startNode.id}',
                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(color: Colors.white12, height: 18),
                                _buildStepRow(1, 'Stand directly at ${widget.startNode.name}'),
                                const SizedBox(height: 6),
                                _buildStepRow(2, 'Point camera straight forward along hallway'),
                                const SizedBox(height: 6),
                                _buildStepRow(3, 'Tap Calibrate to anchor AR 3D space'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          icon: _isCalibrating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.center_focus_strong, size: 22),
                          label: Text(
                            _isCalibrating ? 'Anchoring AR Space...' : 'Calibrate & Start AR Guidance',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 4,
                            shadowColor: AppColors.primaryBlue.withValues(alpha: 0.5),
                          ),
                          onPressed: _isCalibrating ? null : _onCalibratePressed,
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

  Widget _buildStepRow(int number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 9,
          backgroundColor: AppColors.accentBlue,
          child: Text(
            '$number',
            style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Color(0xFFF1F5F9), fontSize: 12),
          ),
        ),
      ],
    );
  }
}
