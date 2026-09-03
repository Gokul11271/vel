import 'dart:math';
import 'package:flutter/material.dart';
import '../models/node.dart';

/// Full-screen animated destination-reached success screen.
class SuccessScreen extends StatefulWidget {
  final Node destination;
  final int totalWaypoints;
  final double totalDistance;
  final int totalSteps;

  const SuccessScreen({
    super.key,
    required this.destination,
    required this.totalWaypoints,
    required this.totalDistance,
    required this.totalSteps,
  });

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _burstController;
  late AnimationController _fadeController;

  late Animation<double> _scaleAnim;
  late Animation<double> _burstAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _burstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _scaleAnim = CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut);
    _burstAnim = CurvedAnimation(parent: _burstController, curve: Curves.easeOut);

    // Sequence: fade in → scale check → burst particles
    _fadeController.forward().then((_) {
      _scaleController.forward().then((_) {
        _burstController.forward();
      });
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _burstController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background gradient
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.3),
                  radius: 1.4,
                  colors: [
                    Color(0xFF0D2B1A),
                    Color(0xFF06100E),
                    Colors.black,
                  ],
                ),
              ),
            ),

            // Burst particle rings
            AnimatedBuilder(
              animation: _burstAnim,
              builder: (context, _) {
                return CustomPaint(
                  painter: _BurstPainter(_burstAnim.value),
                );
              },
            ),

            // Main content
            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // Check icon with scale animation
                  ScaleTransition(
                    scale: _scaleAnim,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.greenAccent.withValues(alpha: 0.15),
                        border: Border.all(color: Colors.greenAccent, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.greenAccent.withValues(alpha: 0.4),
                            blurRadius: 40,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 80,
                        color: Colors.greenAccent,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Title
                  const Text(
                    'Destination Reached!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.destination.name,
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Stats row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatCard(
                          icon: Icons.route_rounded,
                          value: '${widget.totalWaypoints}',
                          label: 'Waypoints',
                          color: Colors.cyanAccent,
                        ),
                        _buildStatCard(
                          icon: Icons.straighten_rounded,
                          value: '${widget.totalDistance.toStringAsFixed(1)}m',
                          label: 'Distance',
                          color: Colors.purpleAccent,
                        ),
                        _buildStatCard(
                          icon: Icons.directions_walk_rounded,
                          value: '${widget.totalSteps}',
                          label: 'Steps',
                          color: Colors.amberAccent,
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 3),

                  // Action buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.home_rounded, size: 20),
                          label: const Text(
                            'Back to Home',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            // Pop to root
                            Navigator.of(context).popUntil((r) => r.isFirst);
                          },
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.navigation_rounded, size: 20),
                          label: const Text(
                            'Navigate Again',
                            style: TextStyle(fontSize: 15),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () {
                            // Go back 2 screens (to destination selector)
                            int count = 0;
                            Navigator.of(context).popUntil((_) => count++ >= 2);
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 36),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      width: 90,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Paints expanding ring burst animations on destination reached
class _BurstPainter extends CustomPainter {
  final double progress;
  _BurstPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.33);
    final rng = Random(42);

    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * pi * 2 + rng.nextDouble() * 0.3;
      final maxRadius = 60.0 + rng.nextDouble() * 80;
      final radius = maxRadius * progress;
      final opacity = (1.0 - progress).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = Colors.greenAccent.withValues(alpha: opacity * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      final offset = Offset(
        center.dx + cos(angle) * radius,
        center.dy + sin(angle) * radius,
      );
      canvas.drawCircle(offset, 3 + progress * 5, paint..style = PaintingStyle.fill..color = Colors.greenAccent.withValues(alpha: opacity * 0.7));
    }

    // Expanding ring
    for (int r = 0; r < 3; r++) {
      final ring = (progress - r * 0.12).clamp(0.0, 1.0);
      if (ring <= 0) continue;
      final ringPaint = Paint()
        ..color = Colors.greenAccent.withValues(alpha: (1 - ring) * 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, ring * 200 + r * 30, ringPaint);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.progress != progress;
}
