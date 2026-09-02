import 'package:flutter/material.dart';
import '../controllers/navigation_controller.dart';
import '../models/pose.dart';
import '../models/node.dart';
import '../algorithms/dijkstra.dart';
import '../services/world_alignment_service.dart';
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
  bool _isCalibrating = false;

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
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _controller.dispose();
    _positionProvider.dispose();
    _arManager.dispose();
    super.dispose();
  }

  void _onCalibratePressed() {
    setState(() {
      _isCalibrating = true;
    });

    // Execute alignment
    _controller.completeCalibration();
    _arManager.setTargetNode(_controller.nextTargetNode);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ World Alignment Calibrated Successfully!'),
        backgroundColor: Colors.green,
        duration: Duration(milliseconds: 900),
      ),
    );

    Future.delayed(const Duration(milliseconds: 500), () {
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final trackingState = _controller.trackingState;
        final isTrackingGood = trackingState == TrackingState.good;

        return Scaffold(
          backgroundColor: const Color(0xFF0F121E),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'World Calibration',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Tracking Quality Badge (Change #9)
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isTrackingGood ? Colors.green.withValues(alpha: 0.2) : Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
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
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            trackingState.label,
                            style: TextStyle(
                              color: isTrackingGood ? Colors.greenAccent : Colors.amberAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Visual Alignment Compass / Target Graphic
                  Expanded(
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer Pulsing Circle
                          ScaleTransition(
                            scale: Tween(begin: 0.9, end: 1.15).animate(_pulseController),
                            child: Container(
                              width: 220,
                              height: 220,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3), width: 2),
                              ),
                            ),
                          ),
                          // Middle Reticle
                          Container(
                            width: 170,
                            height: 170,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.7), width: 2),
                              color: Colors.deepPurple.withValues(alpha: 0.25),
                            ),
                          ),
                          // Calibration Icon
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.explore_rounded,
                                size: 70,
                                color: Colors.cyanAccent,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'ALIGN FORWARD',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Calibration Instructions Card
                  Card(
                    color: const Color(0xFF1E2337),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.pin_drop, color: Colors.cyanAccent, size: 22),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Origin: ${widget.startNode.name}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(color: Colors.white12, height: 20),
                          _buildStepRow(1, 'Stand directly at ${widget.startNode.name}'),
                          const SizedBox(height: 8),
                          _buildStepRow(2, 'Point phone camera forward down corridor'),
                          const SizedBox(height: 8),
                          _buildStepRow(3, 'Tap Calibrate to establish AR world anchor'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Calibrate Button
                  ElevatedButton.icon(
                    icon: _isCalibrating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                          )
                        : const Icon(Icons.center_focus_strong, size: 24),
                    label: Text(
                      _isCalibrating ? 'Calibrating Anchor...' : 'Calibrate & Start AR Guidance',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 6,
                    ),
                    onPressed: _isCalibrating ? null : _onCalibratePressed,
                  ),
                ],
              ),
            ),
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
          radius: 10,
          backgroundColor: Colors.cyanAccent.withValues(alpha: 0.2),
          child: Text(
            '$number',
            style: const TextStyle(fontSize: 11, color: Colors.cyanAccent, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
