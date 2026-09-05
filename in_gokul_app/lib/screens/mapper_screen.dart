import 'dart:math';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/node.dart';
import '../models/edge.dart';
import '../models/building_map.dart';
import '../services/json_service.dart';
import '../tracking/native_ar_position_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/qr_export_dialog.dart';

/// Mobile Mapper Screen
/// Walk a corridor tapping "+" to drop nodes at your current position.
/// The mapper auto-builds bidirectional edges between consecutive nodes,
/// then saves a BuildingMap JSON to device storage and optionally shares it.
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
  late final NativeArPositionProvider _posProvider;
  bool _saving = false;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _posProvider = NativeArPositionProvider();
    _posProvider.start(); // async — fires sensor listeners

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.90, end: 1.10).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _posProvider.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Node management ───────────────────────────────────────────────────────

  void _addNode() {
    final pos = _posProvider.currentPose.position;
    final id = _nodes.isEmpty ? 0 : _nodes.last.id + 1;
    final name = id == 0
        ? '🚪 Entrance'
        : id == 1
            ? 'Waypoint 1'
            : 'Waypoint $id';

    setState(() {
      _nodes.add(Node(id: id, name: name, x: pos.x, y: pos.y, z: pos.z));
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📍 $name added'),
        duration: const Duration(milliseconds: 900),
        backgroundColor: AppColors.primaryBlue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _undoLast() {
    if (_nodes.isEmpty) return;
    setState(() => _nodes.removeLast());
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

      // Share sheet
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
        // Automatically pop up Entrance QR dialog for printing/placement
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
    return Scaffold(
      backgroundColor: AppColors.creamBg,
      appBar: AppBar(
        backgroundColor: AppColors.creamBg,
        foregroundColor: AppColors.textDark,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🗺️ Mapper',
                style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 18)),
            Text(
              widget.buildingName,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
        actions: [
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
          // ── Status banner ───────────────────────────────────────────────
          _buildStatusBanner(),

          // ── Node chip list ──────────────────────────────────────────────
          Expanded(
            child: _nodes.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.softBlue,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.softBlueBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.my_location_rounded, color: AppColors.primaryBlue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _nodes.isEmpty
                  ? 'Stand at the entrance and tap ➕ to drop the first node.'
                  : '${_nodes.length} node${_nodes.length == 1 ? '' : 's'} mapped'
                      ' · ${_buildEdges().length ~/ 2} edges'
                      ' · Long-press to rename',
              style: const TextStyle(color: AppColors.primaryBlue, fontSize: 13, fontWeight: FontWeight.w500),
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
          Icon(Icons.map_outlined,
              size: 72, color: AppColors.textSubtle.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          const Text('No nodes yet',
              style: TextStyle(color: AppColors.textMuted, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('Walk to a location and tap ➕',
              style: TextStyle(color: AppColors.textSubtle, fontSize: 13)),
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
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.creamSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isFirst ? AppColors.primaryBlue : AppColors.creamBorder),
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
            // Step dot
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotBg,
                border: Border.all(color: dotColor.withValues(alpha: 0.4), width: 1.5),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                      color: dotColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(node.name,
                      style: const TextStyle(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  Text(
                    '(${node.x.toStringAsFixed(2)}, ${node.y.toStringAsFixed(2)}, ${node.z.toStringAsFixed(2)})',
                    style: const TextStyle(color: AppColors.textSubtle, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (isFirst)
              const Icon(Icons.door_front_door_rounded,
                  color: AppColors.primaryBlue, size: 18),
            if (isLast && _nodes.length > 1)
              const Icon(Icons.flag_rounded,
                  color: AppColors.warning, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            // Save button
            Expanded(
              child: ElevatedButton.icon(
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(_saving ? 'Saving…' : '💾 Save Map'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                onPressed: _saving || _nodes.length < 2 ? null : _saveMap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
