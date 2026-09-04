import 'package:flutter/material.dart';

/// Animated waypoint proximity & arrival marker.
///
/// Shows when [distanceToNode] ≤ [showWithinMeters] (default 8 m).
/// States:
///   - Approaching: "📍 Node Name  2.3 m"  — pulsing amber pill
///   - Reached: cross-fades to "✓ Node Reached"  — green flash → fades out after 1.5 s
class WaypointMarker extends StatefulWidget {
  final String nodeName;
  final double distanceToNode;
  final bool waypointReached;

  /// Distance threshold (meters) at which the marker becomes visible.
  final double showWithinMeters;

  const WaypointMarker({
    super.key,
    required this.nodeName,
    required this.distanceToNode,
    required this.waypointReached,
    this.showWithinMeters = 8.0,
  });

  @override
  State<WaypointMarker> createState() => _WaypointMarkerState();
}

class _WaypointMarkerState extends State<WaypointMarker>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _reachedCtrl;
  late AnimationController _fadeOutCtrl;
  late Animation<double> _pulseAnim;
  late Animation<double> _reachedFade;
  late Animation<double> _fadeOut;

  bool _showingReached = false;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _reachedCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeOutCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _reachedFade = CurvedAnimation(parent: _reachedCtrl, curve: Curves.easeIn);
    _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeOutCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(WaypointMarker old) {
    super.didUpdateWidget(old);
    if (!old.waypointReached && widget.waypointReached && !_showingReached) {
      _triggerReachedAnimation();
    }
  }

  Future<void> _triggerReachedAnimation() async {
    _showingReached = true;
    await _reachedCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 1000));
    if (mounted) await _fadeOutCtrl.forward();
    if (mounted) {
      setState(() => _showingReached = false);
      _reachedCtrl.reset();
      _fadeOutCtrl.reset();
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _reachedCtrl.dispose();
    _fadeOutCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVisible = widget.distanceToNode <= widget.showWithinMeters;
    if (!isVisible && !_showingReached) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnim, _reachedFade, _fadeOut]),
      builder: (context, _) {
        final opacity = _showingReached ? _fadeOut.value : 1.0;
        return Opacity(
          opacity: opacity,
          child: _showingReached
              ? _buildReachedChip()
              : _buildApproachChip(),
        );
      },
    );
  }

  Widget _buildApproachChip() {
    return ScaleTransition(
      scale: _pulseAnim,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.80),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Colors.amberAccent.withValues(alpha: 0.85),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.amberAccent.withValues(alpha: 0.25),
              blurRadius: 14,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on_rounded,
                color: Colors.amberAccent, size: 18),
            const SizedBox(width: 8),
            Text(
              widget.nodeName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${widget.distanceToNode.toStringAsFixed(1)} m',
              style: const TextStyle(
                color: Colors.amberAccent,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReachedChip() {
    return FadeTransition(
      opacity: _reachedFade,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.greenAccent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.greenAccent, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.greenAccent.withValues(alpha: 0.35),
              blurRadius: 18,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.greenAccent, size: 20),
            const SizedBox(width: 8),
            Text(
              '${widget.nodeName}  Reached',
              style: const TextStyle(
                color: Colors.greenAccent,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
