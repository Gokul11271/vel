import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import '../models/node.dart';
import '../models/edge.dart';
import '../models/building_map.dart';
import '../models/pose.dart';
import '../models/ar_pose.dart';
import '../services/json_service.dart';
import '../services/android_ar_service.dart';
import '../tracking/native_ar_position_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/qr_export_dialog.dart';
import '../widgets/native_ar_view_widget.dart';

/// Mobile Mapper Screen (Phase 7 Walkthrough Mapping Tool)
/// Walk a corridor tapping "+" to drop nodes at your current position.
/// Real-time top-down canvas visualizes the walked trail, node pins, and edges.
/// Auto-builds bidirectional edges and exports QR origin alignment data.
class MapperScreen extends StatefulWidget {
  final String buildingId;
  final String buildingName;

  const MapperScreen({
    super.key,
    this.buildingId = 'building_01',
    this.buildingName = 'New Building',
  });

  @override
  State<MapperScreen> createState() => _MapperScreenState();
}

class _MapperScreenState extends State<MapperScreen>
    with SingleTickerProviderStateMixin {
  final List<Node> _nodes = [];
  final List<Vector3> _liveTrail = [];
  late final NativeArPositionProvider _posProvider;
  final AndroidARService _arService = AndroidARService();
  StreamSubscription<Pose>? _poseSubscription;
  StreamSubscription<ARPose>? _arPoseSubscription;
  bool _saving = false;
  bool _isARMode = false;
  bool _isARSupported = false;
  int _placedAnchorCount = 0;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _posProvider = NativeArPositionProvider();
    _posProvider.start();
    _posProvider.resetSession();

    _poseSubscription = _posProvider.poseStream.listen((pose) {
      if (mounted) {
        setState(() {
          final pos = pose.position;
          if (_liveTrail.isEmpty || (_liveTrail.last - pos).length > 0.3) {
            _liveTrail.add(pos.clone());
            if (_liveTrail.length > 200) {
              _liveTrail.removeAt(0);
            }
          }
        });
      }
    });

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.90, end: 1.10).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _checkARSupport();
  }

  Future<void> _checkARSupport() async {
    final supported = await _arService.isARSupported();
    if (mounted) {
      setState(() => _isARSupported = supported);
    }
  }

  Future<void> _toggleARMode() async {
    if (!_isARMode) {
      final supported = await _arService.isARSupported();
      if (!supported) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Google ARCore is not supported or not installed on this device.'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
        return;
      }

      final hasPerm = await _arService.checkCameraPermission() ||
          await _arService.requestCameraPermission();
      if (!hasPerm) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Camera permission is required for 3D AR Mapping.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      final started = await _arService.startARSession();
      if (!started) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Failed to start ARCore session.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      // Sync existing nodes to ARCore anchors
      for (final n in _nodes) {
        await _arService.addNodeAnchor(n.x, n.y, n.z);
      }
      _syncARRouteRibbon();

      if (mounted) {
        setState(() => _isARMode = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ 3D ARCore View Activated! Tapping "+" drops physical 3D beacons.'),
            backgroundColor: AppColors.primaryBlue,
            duration: Duration(milliseconds: 1600),
          ),
        );
      }
    } else {
      await _arService.pauseARSession();
      if (mounted) {
        setState(() => _isARMode = false);
      }
    }
  }

  void _syncARRouteRibbon() {
    if (!_isARMode) return;
    final points = _nodes.map((n) => Vector3D(x: n.x, y: n.y, z: n.z)).toList();
    final dest = points.isNotEmpty ? points.last : const Vector3D();
    _arService.updateNavigationRoute(points, dest);
  }

  @override
  void dispose() {
    _poseSubscription?.cancel();
    _arPoseSubscription?.cancel();
    _posProvider.dispose();
    _pulseCtrl.dispose();
    _arService.clearNodeAnchors();
    _arService.clearNavigationRoute();
    _arService.stopARSession();
    _arService.dispose();
    super.dispose();
  }

  // ── Node management ───────────────────────────────────────────────────────

  void _addNode() async {
    final pos = _posProvider.currentPose.position;

    // MINIMUM DISTANCE: Avoid overlapping identical node positions (< 0.8m)
    if (_nodes.isNotEmpty) {
      final lastNode = _nodes.last;
      final dx = pos.x - lastNode.x;
      final dz = pos.z - lastNode.z;
      final distFromLast = sqrt(dx * dx + dz * dz);

      if (distFromLast < 0.8) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '⚠️ Move at least 0.8m before dropping next node (Currently ${distFromLast.toStringAsFixed(1)}m away)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: AppColors.warning,
            duration: const Duration(milliseconds: 1400),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    final id = _nodes.isEmpty ? 0 : _nodes.last.id + 1;
    final name = id == 0
        ? '🚪 Entrance'
        : id == 1
            ? 'Waypoint 1'
            : 'Waypoint $id';

    debugPrint(
        'DEBUG MAPPER -> Steps: ${_posProvider.totalSteps} | Dropped Node: $name at (${pos.x.toStringAsFixed(2)}, ${pos.z.toStringAsFixed(2)})');

    setState(() {
      _nodes.add(Node(id: id, name: name, x: pos.x, y: pos.y, z: pos.z));
      _placedAnchorCount++;
    });

    // If AR mode is active, drop native 3D spatial anchor and update ribbon
    if (_isARMode) {
      await _arService.addNodeAnchor(pos.x, pos.y, pos.z);
      _syncARRouteRibbon();
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isARMode
            ? '📍 3D AR Beacon $name dropped at (${pos.x.toStringAsFixed(1)}, ${pos.z.toStringAsFixed(1)})'
            : '📍 $name added at (${pos.x.toStringAsFixed(1)}, ${pos.z.toStringAsFixed(1)})'),
        duration: const Duration(milliseconds: 1000),
        backgroundColor: AppColors.primaryBlue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _undoLast() async {
    if (_nodes.isEmpty) return;
    setState(() {
      _nodes.removeLast();
      if (_placedAnchorCount > 0) _placedAnchorCount--;
    });

    if (_isARMode) {
      await _arService.clearNodeAnchors();
      for (final n in _nodes) {
        await _arService.addNodeAnchor(n.x, n.y, n.z);
      }
      _syncARRouteRibbon();
    }
  }

  void _markDestination() {
    if (_nodes.isEmpty) return;
    final last = _nodes.last;
    setState(() {
      _nodes[_nodes.length - 1] = Node(
        id: last.id,
        name: '🏁 Destination',
        x: last.x,
        y: last.y,
        z: last.z,
      );
    });
  }

  void _renameNode(int index) async {
    final ctrl = TextEditingController(text: _nodes[index].name);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.creamSurface,
        title: const Text('Rename Node', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AppColors.textDark),
          decoration: const InputDecoration(
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.creamBorder),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.primaryBlue, width: 2),
            ),
          ),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Save', style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && mounted) {
      setState(() {
        final n = _nodes[index];
        _nodes[index] = Node(id: n.id, name: result, x: n.x, y: n.y, z: n.z);
      });
    }
  }

  // ── Build edges ────────────────────────────────────────────────────────────

  List<Edge> _buildEdges() {
    final edges = <Edge>[];
    for (int i = 0; i < _nodes.length - 1; i++) {
      final n1 = _nodes[i];
      final n2 = _nodes[i + 1];
      final dx = n1.x - n2.x;
      final dy = n1.y - n2.y;
      final dz = n1.z - n2.z;
      final dist = sqrt(dx * dx + dy * dy + dz * dz);
      edges.add(Edge(sourceId: n1.id, targetId: n2.id, weight: dist));
      edges.add(Edge(sourceId: n2.id, targetId: n1.id, weight: dist));
    }
    return edges;
  }

  // ── Save & Share ────────────────────────────────────────────────────────────

  Future<void> _saveMap() async {
    if (_nodes.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least 2 nodes before saving.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final map = BuildingMap(
        buildingId: widget.buildingId,
        buildingName: widget.buildingName,
        entranceNodeId: _nodes.first.id,
        nodes: _nodes,
        edges: _buildEdges(),
      );

      final file = await JsonService.saveNavigationJson(map);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '${widget.buildingName} — navigation map',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Map saved to ${file.path}'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        QrExportDialog.show(
          context,
          buildingId: widget.buildingId,
          buildingName: widget.buildingName,
          entranceName: _nodes.first.name,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Save failed: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final curPose = _posProvider.currentPose;
    final headingDeg = (curPose.yawDegrees + 360) % 360;

    return Scaffold(
      backgroundColor: AppColors.creamBg,
      appBar: AppBar(
        backgroundColor: AppColors.creamBg,
        foregroundColor: AppColors.textDark,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🗺️ Mobile Mapper',
                style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 18)),
            Text(
              widget.buildingName,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isARMode ? Icons.view_in_ar_rounded : Icons.map_rounded,
              color: _isARMode ? AppColors.primaryBlue : AppColors.textMuted,
            ),
            tooltip: _isARMode ? 'Switch to 2D Map View' : 'Switch to 3D ARCore View',
            onPressed: _toggleARMode,
          ),
          if (_nodes.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.qr_code_2_rounded, color: AppColors.primaryBlue),
              tooltip: 'Export Entrance QR Code',
              onPressed: () => QrExportDialog.show(
                context,
                buildingId: widget.buildingId,
                buildingName: widget.buildingName,
                entranceName: _nodes.first.name,
              ),
            ),
          if (_nodes.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.undo_rounded, color: AppColors.textMuted),
              tooltip: 'Undo last node',
              onPressed: _undoLast,
            ),
          if (_nodes.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.flag_rounded, color: AppColors.primaryBlue, size: 18),
              label: const Text('Mark Dest.',
                  style: TextStyle(color: AppColors.primaryBlue, fontSize: 13, fontWeight: FontWeight.bold)),
              onPressed: _markDestination,
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Real-time Walk View: 3D AR Surface or Top-Down 2D Canvas ────
          Container(
            height: _isARMode ? 260 : 210,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                if (_isARMode)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: const SizedBox.expand(
                      child: NativeARViewWidget(),
                    ),
                  )
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: CustomPaint(
                      size: const Size(double.infinity, 210),
                      painter: _MapperRadarPainter(
                        nodes: _nodes,
                        trail: _liveTrail,
                        currentPose: curPose,
                      ),
                    ),
                  ),
                // Telemetry overlay badge
                Positioned(
                  top: 10,
                  left: 12,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.70),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isARMode ? Icons.view_in_ar_rounded : Icons.explore_rounded,
                              color: _isARMode ? Colors.cyanAccent : Colors.amberAccent,
                              size: 14,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _isARMode
                                  ? '3D ARCore | ${_nodes.length} Beacons'
                                  : '${headingDeg.toStringAsFixed(0)}°  |  ${_posProvider.totalSteps} steps',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _posProvider.manualStep();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.directions_walk_rounded, color: Colors.white, size: 14),
                              SizedBox(width: 3),
                              Text(
                                '+ Step',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.70),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '(${curPose.position.x.toStringAsFixed(1)}, ${curPose.position.z.toStringAsFixed(1)}) m',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Status banner ───────────────────────────────────────────────
          _buildStatusBanner(),

          // ── Node list ───────────────────────────────────────────────────
          Expanded(
            child: _nodes.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _nodes.length,
                    itemBuilder: (_, i) => _buildNodeTile(i),
                  ),
          ),

          // ── Bottom actions ──────────────────────────────────────────────
          _buildBottomBar(),
        ],
      ),
      // ── FAB — Add Node ─────────────────────────────────────────────────
      floatingActionButton: ScaleTransition(
        scale: _pulseAnim,
        child: FloatingActionButton.large(
          onPressed: _addNode,
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          tooltip: 'Add node at current position',
          elevation: 6,
          child: const Icon(Icons.add_location_alt_rounded, size: 34),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: const SizedBox(height: 100),
    );
  }

  Widget _buildStatusBanner() {
    final curPos = _posProvider.currentPose.position;
    double distFromLast = 0.0;
    bool canDrop = false;

    if (_nodes.isNotEmpty) {
      final lastNode = _nodes.last;
      final dx = curPos.x - lastNode.x;
      final dz = curPos.z - lastNode.z;
      distFromLast = sqrt(dx * dx + dz * dz);
      canDrop = distFromLast >= 0.8;
    } else {
      canDrop = true;
    }

    final bannerBg = _nodes.isEmpty
        ? AppColors.softBlue
        : canDrop
            ? const Color(0xFFDCFCE7) // Soft Green
            : const Color(0xFFFEF3C7); // Soft Amber

    final bannerBorder = _nodes.isEmpty
        ? AppColors.softBlueBorder
        : canDrop
            ? const Color(0xFF86EFAC)
            : const Color(0xFFFCD34D);

    final iconColor = _nodes.isEmpty
        ? AppColors.primaryBlue
        : canDrop
            ? const Color(0xFF16A34A)
            : const Color(0xFFD97706);

    final text = _nodes.isEmpty
        ? 'Stand at entrance and tap ➕ to drop Entrance Node.'
        : canDrop
            ? '✅ Ready to drop node (${distFromLast.toStringAsFixed(1)} m from last node)'
            : '🚶 Walk ${(0.8 - distFromLast).clamp(0.0, 0.8).toStringAsFixed(1)} m more to drop next node (${distFromLast.toStringAsFixed(1)} m / 0.8 m)';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bannerBorder),
      ),
      child: Row(
        children: [
          Icon(canDrop ? Icons.check_circle_rounded : Icons.directions_walk_rounded,
              color: iconColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: iconColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.directions_walk_rounded,
              size: 56, color: AppColors.textSubtle.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          const Text('Walk along corridor and tap ➕ to drop nodes',
              style: TextStyle(color: AppColors.textMuted, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildNodeTile(int index) {
    final node = _nodes[index];
    final isFirst = index == 0;
    final isLast = index == _nodes.length - 1;
    Color dotBg = AppColors.softBlue;
    Color dotColor = AppColors.primaryBlue;
    if (isFirst) {
      dotBg = AppColors.primaryBlue;
      dotColor = Colors.white;
    }
    if (isLast && _nodes.length > 1) {
      dotBg = const Color(0xFFFEF3C7);
      dotColor = AppColors.warning;
    }

    return GestureDetector(
      onLongPress: () => _renameNode(index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.creamSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isFirst ? AppColors.primaryBlue : AppColors.creamBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotBg,
                border: Border.all(color: dotColor.withValues(alpha: 0.4), width: 1.5),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(color: dotColor, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(node.name,
                      style: const TextStyle(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  Text(
                    '(${node.x.toStringAsFixed(2)}, ${node.z.toStringAsFixed(2)}) m',
                    style: const TextStyle(color: AppColors.textSubtle, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (isFirst)
              const Icon(Icons.door_front_door_rounded, color: AppColors.primaryBlue, size: 16),
            if (isLast && _nodes.length > 1)
              const Icon(Icons.flag_rounded, color: AppColors.warning, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: ElevatedButton.icon(
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.save_rounded, size: 18),
          label: Text(_saving ? 'Saving…' : '💾 Save Map & Export QR'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _saving || _nodes.length < 2 ? null : _saveMap,
        ),
      ),
    );
  }
}

/// Custom radar canvas for live PDR walking trail and node pins
class _MapperRadarPainter extends CustomPainter {
  final List<Node> nodes;
  final List<Vector3> trail;
  final Pose currentPose;

  _MapperRadarPainter({
    required this.nodes,
    required this.trail,
    required this.currentPose,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.5;
    final cy = size.height * 0.5;

    // Grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1.0;
    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    const scale = 14.0; // 14 pixels per metre

    // Draw trail
    if (trail.length >= 2) {
      final trailPath = Path();
      for (int i = 0; i < trail.length; i++) {
        final sx = cx + trail[i].x * scale;
        final sy = cy + trail[i].z * scale;
        if (i == 0) {
          trailPath.moveTo(sx, sy);
        } else {
          trailPath.lineTo(sx, sy);
        }
      }
      final trailPaint = Paint()
        ..color = Colors.cyanAccent.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawPath(trailPath, trailPaint);
    }

    // Draw node edges
    if (nodes.length >= 2) {
      final edgePaint = Paint()
        ..color = AppColors.lightBlue.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      for (int i = 0; i < nodes.length - 1; i++) {
        final p1 = Offset(cx + nodes[i].x * scale, cy + nodes[i].z * scale);
        final p2 = Offset(cx + nodes[i + 1].x * scale, cy + nodes[i + 1].z * scale);
        canvas.drawLine(p1, p2, edgePaint);
      }
    }

    // Draw node pins
    for (int i = 0; i < nodes.length; i++) {
      final n = nodes[i];
      final pt = Offset(cx + n.x * scale, cy + n.z * scale);
      final isFirst = i == 0;
      final isLast = i == nodes.length - 1;

      final pinPaint = Paint()
        ..color = isFirst
            ? Colors.greenAccent
            : isLast
                ? Colors.amberAccent
                : AppColors.primaryBlue
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pt, 6.0, pinPaint);

      final strokePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(pt, 6.0, strokePaint);
    }

    // Draw live user position dot and heading beam
    final userX = cx + currentPose.position.x * scale;
    final userY = cy + currentPose.position.z * scale;
    final userPt = Offset(userX, userY);

    // Directional cone
    final yaw = currentPose.yawRadians;
    final conePaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    final conePath = Path();
    conePath.moveTo(userPt.dx, userPt.dy);
    final len = 28.0;
    conePath.lineTo(userPt.dx + len * sin(yaw - 0.4), userPt.dy - len * cos(yaw - 0.4));
    conePath.lineTo(userPt.dx + len * sin(yaw + 0.4), userPt.dy - len * cos(yaw + 0.4));
    conePath.close();
    canvas.drawPath(conePath, conePaint);

    // User dot
    final userPaint = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.fill;
    canvas.drawCircle(userPt, 5.0, userPaint);
  }

  @override
  bool shouldRepaint(covariant _MapperRadarPainter oldDelegate) => true;
}

