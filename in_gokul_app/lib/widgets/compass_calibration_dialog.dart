import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CompassCalibrationSheet extends StatefulWidget {
  final VoidCallback onDismissed;

  const CompassCalibrationSheet({super.key, required this.onDismissed});

  static void show(BuildContext context, {required VoidCallback onDismissed}) {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CompassCalibrationSheet(onDismissed: onDismissed),
    );
  }

  @override
  State<CompassCalibrationSheet> createState() => _CompassCalibrationSheetState();
}

class _CompassCalibrationSheetState extends State<CompassCalibrationSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _figure8Anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _figure8Anim = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.navyDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0xFF334155), width: 1.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Icon(Icons.explore_off_rounded, color: Colors.amberAccent, size: 28),
              SizedBox(width: 12),
              Text(
                "Calibrate Compass",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            "Indoor magnetic interference detected. Wave your phone in a smooth 3D figure-8 pattern to recalibrate direction.",
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 24),
          // Animated Figure-8 visualizer
          SizedBox(
            height: 90,
            width: 220,
            child: AnimatedBuilder(
              animation: _figure8Anim,
              builder: (context, child) {
                return CustomPaint(
                  painter: _Figure8Painter(_controller.value),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                widget.onDismissed();
              },
              child: const Text(
                "I've Calibrated / Dismiss",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _Figure8Painter extends CustomPainter {
  final double progress;
  _Figure8Painter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final trackPaint = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final dotPaint = Paint()
      ..color = AppColors.lightBlue
      ..style = PaintingStyle.fill;

    final glowPaint = Paint()
      ..color = AppColors.lightBlue.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final path = Path();

    // Draw smooth figure-8 track (Lemniscate shape)
    path.moveTo(center.dx - 60, center.dy);
    path.cubicTo(center.dx - 60, center.dy - 40, center.dx + 60, center.dy + 40, center.dx + 60, center.dy);
    path.cubicTo(center.dx + 60, center.dy - 40, center.dx - 60, center.dy + 40, center.dx - 60, center.dy);
    canvas.drawPath(path, trackPaint);

    // Compute moving position along path
    final metrics = path.computeMetrics().toList();
    if (metrics.isNotEmpty) {
      final metric = metrics.first;
      final tangent = metric.getTangentForOffset(metric.length * progress);
      if (tangent != null) {
        canvas.drawCircle(tangent.position, 12, glowPaint);
        canvas.drawCircle(tangent.position, 6, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Figure8Painter oldDelegate) => oldDelegate.progress != progress;
}
