import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../controllers/navigation_controller.dart';
import '../models/pose.dart';
import '../models/node.dart';
import '../algorithms/dijkstra.dart';
import '../services/world_alignment_service.dart';
import '../services/camera_service.dart';
import '../tracking/native_ar_position_provider.dart';
import '../ar/ar_manager.dart';
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

    _setupCamera();
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
        backgroundColor: Colors.green,
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
                      colors: [Color(0xFF0F121E), Color(0xFF1E2337)],
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
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.85),
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
                              border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.4), width: 2),
                            ),
                          ),
                        ),
                        // Reticle Glass Ring
                        Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.cyanAccent, width: 2),
                            color: Colors.cyanAccent.withValues(alpha: 0.08),
                          ),
                        ),
                        // Center Calibration Icon
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.explore_rounded,
                              size: 56,
                              color: Colors.cyanAccent,
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
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.5)),
                      ),
                      child: const Text(
                        'ALIGN CAMERA DOWN CORRIDOR',
                        style: TextStyle(
                          color: Colors.cyanAccent,
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
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isTrackingGood
                                  ? Colors.green.withValues(alpha: 0.25)
                                  : Colors.amber.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isTrackingGood ? Colors.greenAccent : Colors.amberAccent,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isTrackingGood ? Icons.sensors : Icons.sensors_off,
                                  color: isTrackingGood ? Colors.greenAccent : Colors.amberAccent,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  trackingState.label,
                                  style: TextStyle(
                                    color: isTrackingGood ? Colors.greenAccent : Colors.amberAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
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
                          color: const Color(0xFF161B2B).withValues(alpha: 0.9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.pin_drop, color: Colors.cyanAccent, size: 20),
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
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.cyanAccent.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Node #${widget.startNode.id}',
                                        style: const TextStyle(color: Colors.cyanAccent, fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(color: Colors.white12, height: 16),
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
                                  child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                                )
                              : const Icon(Icons.center_focus_strong, size: 22),
                          label: Text(
                            _isCalibrating ? 'Anchoring AR Space...' : 'Calibrate & Start AR Guidance',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyanAccent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 8,
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
          backgroundColor: Colors.cyanAccent.withValues(alpha: 0.2),
          child: Text(
            '$number',
            style: const TextStyle(fontSize: 10, color: Colors.cyanAccent, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
