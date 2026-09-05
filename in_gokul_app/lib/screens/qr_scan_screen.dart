import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/building_map.dart';
import '../models/graph.dart';
import '../models/node.dart';
import '../algorithms/dijkstra.dart';
import '../services/json_service.dart';
import '../theme/app_theme.dart';
import 'navigation_screen.dart';

/// QR scan screen — Phase B of the Indoor AR Navigation prototype.
///
/// Flow:
///   1. Point camera at a QR code containing:
///         {"building":"main_block","entrance":1}
///      or simply the building ID as plain text.
///   2. App loads the matching BuildingMap (from documents; falls back to asset).
///   3. User picks destination → taps "I'm Here" → AR navigation starts.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

enum _Phase { scanning, loading, confirm, error }

class _QrScanScreenState extends State<QrScanScreen>
    with TickerProviderStateMixin {
  // ── Scanner ────────────────────────────────────────────────────────────────
  late MobileScannerController _scannerCtrl;
  bool _scanned = false;

  // ── State machine ──────────────────────────────────────────────────────────
  _Phase _phase = _Phase.scanning;
  String? _errorMessage;

  // ── Loaded data ────────────────────────────────────────────────────────────
  BuildingMap? _buildingMap;
  Graph? _graph;
  Node? _entranceNode;
  Node? _selectedDestination;

  // ── Animations ─────────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    _scannerCtrl = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _scannerCtrl.dispose();
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── QR detection ──────────────────────────────────────────────────────────

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;
    _scanned = true;
    _scannerCtrl.stop();
    _handleQrValue(barcode!.rawValue!);
  }

  double? _scannedHeadingDegrees;

  Future<void> _handleQrValue(String raw) async {
    setState(() => _phase = _Phase.loading);

    try {
      // Parse QR — accept JSON object or plain building ID
      String buildingId;
      int? qrEntranceId;
      double? qrHeading;

      if (raw.trimLeft().startsWith('{')) {
        final dynamic decoded = jsonDecode(raw);
        final map = decoded as Map<String, dynamic>? ?? {};
        buildingId = map['building'] as String? ?? raw.trim();
        if (map['entrance'] != null) {
          qrEntranceId = (map['entrance'] as num).toInt();
        }
        if (map['heading'] != null) {
          qrHeading = (map['heading'] as num).toDouble();
        }
      } else {
        buildingId = raw.trim();
      }

      _scannedHeadingDegrees = qrHeading;

      // Load saved map; fall back to bundled asset
      BuildingMap? map = await JsonService.loadSavedMap();
      if (map == null || map.buildingId != buildingId) {
        final graph = await JsonService.loadNavigationGraph();
        map = BuildingMap(
          buildingId: buildingId,
          buildingName: buildingId
              .replaceAll('_', ' ')
              .split(' ')
              .map((w) => w.isEmpty
                  ? w
                  : w[0].toUpperCase() + w.substring(1))
              .join(' '),
          entranceNodeId: qrEntranceId ??
              (graph.nodes.values.isNotEmpty
                  ? graph.nodes.values.first.id
                  : 0),
          nodes: graph.nodes.values.toList(),
          edges: graph.edges,
        );
      }

      final graph = map.toGraph();
      final entranceId = qrEntranceId ?? map.entranceNodeId;
      final entrance =
          graph.nodes[entranceId] ?? graph.nodes.values.firstOrNull;

      if (entrance == null) throw Exception('Building map has no nodes.');

      if (mounted) {
        setState(() {
          _buildingMap = map;
          _graph = graph;
          _entranceNode = entrance;
          _phase = _Phase.confirm;
        });
        _fadeCtrl.forward(from: 0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _phase = _Phase.error;
        });
      }
    }
  }

  // ── Navigate ──────────────────────────────────────────────────────────────

  void _startNavigation() {
    final dest = _selectedDestination;
    final start = _entranceNode;
    final graph = _graph;
    if (dest == null || start == null || graph == null) return;

    final routeResult = Dijkstra.findShortestPath(graph, start.id, dest.id);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => NavigationScreen(
          startNode: start,
          targetNode: dest,
          routeResult: routeResult,
          initialHeadingDegrees: _scannedHeadingDegrees,
        ),
      ),
    );
  }

  void _reset() {
    setState(() {
      _scanned = false;
      _phase = _Phase.scanning;
      _errorMessage = null;
      _buildingMap = null;
      _graph = null;
      _entranceNode = null;
      _selectedDestination = null;
    });
    _scannerCtrl.start();
    _fadeCtrl.reset();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _phase == _Phase.confirm ? AppColors.creamBg : const Color(0xFF0F172A),
      body: Stack(
        children: [
          // Phase content
          switch (_phase) {
            _Phase.scanning => _buildScanView(),
            _Phase.loading  => _buildLoadingView(),
            _Phase.confirm  => _buildConfirmView(),
            _Phase.error    => _buildErrorView(),
          },

          // Back button (always visible)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _phase == _Phase.confirm
                        ? AppColors.creamSurface
                        : Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                    border: _phase == _Phase.confirm
                        ? Border.all(color: AppColors.creamBorder)
                        : null,
                    boxShadow: [
                      if (_phase == _Phase.confirm)
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                        ),
                    ],
                  ),
                  child: Icon(Icons.arrow_back_ios_new,
                      color: _phase == _Phase.confirm ? AppColors.textDark : Colors.white,
                      size: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Scan phase ─────────────────────────────────────────────────────────────

  Widget _buildScanView() {
    return Stack(
      children: [
        // Live camera
        MobileScanner(controller: _scannerCtrl, onDetect: _onDetect),

        // Vignette
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withValues(alpha: 0.75),
                Colors.transparent,
                Colors.transparent,
                Colors.black.withValues(alpha: 0.85),
              ],
              stops: const [0.0, 0.25, 0.65, 1.0],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),

        SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 64),
              const Text(
                'Scan Building QR',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Point camera at the entrance QR code',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
              const Spacer(),

              // Animated scan frame
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (context, _) {
                  final glow = _pulseCtrl.value;
                  return Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.lightBlue
                            .withValues(alpha: 0.5 + glow * 0.5),
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              AppColors.primaryBlue.withValues(alpha: glow * 0.35),
                          blurRadius: 30,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        ..._buildCorners(),
                        // Scan sweep line
                        Positioned(
                          top: 220 * (0.1 + _pulseCtrl.value * 0.8),
                          left: 10,
                          right: 10,
                          child: Container(
                            height: 2,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  AppColors.lightBlue,
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.navyDark.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.lightBlue.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: AppColors.lightBlue, size: 16),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '{"building":"main_block","entrance":1}',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildCorners() {
    const s = 22.0;
    const t = 3.0;
    const c = AppColors.lightBlue;
    return [
      Positioned(top: 0, left: 0,
          child: _Corner(size: s, thick: t, color: c, top: true, left: true)),
      Positioned(top: 0, right: 0,
          child: _Corner(size: s, thick: t, color: c, top: true, left: false)),
      Positioned(bottom: 0, left: 0,
          child: _Corner(size: s, thick: t, color: c, top: false, left: true)),
      Positioned(bottom: 0, right: 0,
          child: _Corner(size: s, thick: t, color: c, top: false, left: false)),
    ];
  }

  // ── Loading phase ─────────────────────────────────────────────────────────

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.primaryBlue),
          SizedBox(height: 20),
          Text('Loading building map…',
              style: TextStyle(color: Colors.white70, fontSize: 16)),
        ],
      ),
    );
  }

  // ── Confirm/Destination phase ──────────────────────────────────────────────

  Widget _buildConfirmView() {
    final map = _buildingMap!;
    final graph = _graph!;
    final entrance = _entranceNode!;
    final destinations = graph.nodes.values
        .where((n) => n.id != entrance.id)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return FadeTransition(
      opacity: _fadeCtrl,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 56),

            // Building header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.softBlue,
                      border: Border.all(
                          color: AppColors.primaryBlue.withValues(alpha: 0.4)),
                    ),
                    child: const Icon(Icons.domain_rounded,
                        color: AppColors.primaryBlue, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          map.buildingName,
                          style: const TextStyle(
                            color: AppColors.textDark,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${map.nodes.length} nodes  •  ${map.buildingId}',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  // Rescan button
                  IconButton(
                    onPressed: _reset,
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.creamSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.creamBorder),
                      ),
                      child: const Icon(Icons.qr_code_scanner_rounded,
                          color: AppColors.primaryBlue, size: 18),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Entrance info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.softBlue,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.softBlueBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.my_location,
                        color: AppColors.primaryBlue, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Stand at entrance: ${entrance.name}',
                        style: const TextStyle(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '✓ QR OK',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'WHERE DO YOU WANT TO GO?',
                style: TextStyle(
                  color: AppColors.textSubtle,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Destination list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: destinations.length,
                itemBuilder: (context, index) {
                  final node = destinations[index];
                  final isSelected = _selectedDestination?.id == node.id;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedDestination = node),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 13),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: isSelected
                            ? AppColors.softBlue
                            : AppColors.creamSurface,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaryBlue
                              : AppColors.creamBorder,
                          width: isSelected ? 1.8 : 1,
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
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? AppColors.primaryBlue
                                  : AppColors.creamSurfaceAlt,
                            ),
                            child: Center(
                              child: Text(
                                '#${node.id}',
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textMuted,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              node.name,
                              style: TextStyle(
                                color:
                                    isSelected ? AppColors.primaryBlue : AppColors.textDark,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded,
                                color: AppColors.primaryBlue, size: 20),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // CTAs
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.explore_rounded, size: 20),
                label: const Text(
                  'I\'m Here — Start Navigation',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedDestination != null
                      ? AppColors.primaryBlue
                      : AppColors.creamSurfaceAlt,
                  foregroundColor: _selectedDestination != null
                      ? Colors.white
                      : AppColors.textSubtle,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: _selectedDestination != null ? 2 : 0,
                  shadowColor: AppColors.primaryBlue.withValues(alpha: 0.35),
                ),
                onPressed: _selectedDestination != null ? _startNavigation : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Error phase ───────────────────────────────────────────────────────────

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 56, color: AppColors.error),
            const SizedBox(height: 16),
            const Text(
              'Could not load building',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                minimumSize: const Size(200, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _reset,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Corner bracket decoration ────────────────────────────────────────────────

class _Corner extends StatelessWidget {
  final double size;
  final double thick;
  final Color color;
  final bool top;
  final bool left;
  const _Corner({
    required this.size,
    required this.thick,
    required this.color,
    required this.top,
    required this.left,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CornerPainter(color: color, thick: thick, top: top, left: left),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double thick;
  final bool top;
  final bool left;
  const _CornerPainter({
    required this.color,
    required this.thick,
    required this.top,
    required this.left,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = thick
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final xCorner = left ? 0.0 : size.width;
    final yCorner = top ? 0.0 : size.height;
    final xFar = left ? size.width : 0.0;
    final yFar = top ? size.height : 0.0;

    canvas.drawPath(
      Path()
        ..moveTo(xFar, yCorner)
        ..lineTo(xCorner, yCorner)
        ..lineTo(xCorner, yFar),
      p,
    );
  }

  @override
  bool shouldRepaint(_CornerPainter old) => false;
}
