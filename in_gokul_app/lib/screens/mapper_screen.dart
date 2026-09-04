import 'dart:math';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/node.dart';
import '../models/edge.dart';
import '../models/building_map.dart';
import '../services/json_service.dart';
import '../tracking/native_ar_position_provider.dart';

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
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.15).animate(
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
        backgroundColor: const Color(0xFF1A2035),
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
        backgroundColor: const Color(0xFF1A2035),
        title: const Text('Rename Node', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.cyanAccent),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.cyanAccent, width: 2),
            ),
          ),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Save', style: TextStyle(color: Colors.cyanAccent)),
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
          backgroundColor: Colors.redAccent,
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
            backgroundColor: Colors.green.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Save failed: $e'),
            backgroundColor: Colors.redAccent,
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
      backgroundColor: const Color(0xFF0A0D17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1120),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🗺️ Mapper',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            Text(
              widget.buildingName,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
        actions: [
          if (_nodes.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.undo_rounded, color: Colors.white54),
              tooltip: 'Undo last node',
              onPressed: _undoLast,
            ),
          if (_nodes.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.flag_rounded, color: Colors.amberAccent, size: 18),
              label: const Text('Mark Dest.',
                  style: TextStyle(color: Colors.amberAccent, fontSize: 12)),
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
          backgroundColor: Colors.cyanAccent,
          foregroundColor: Colors.black,
          tooltip: 'Add node at current position',
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.cyanAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.my_location_rounded, color: Colors.cyanAccent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _nodes.isEmpty
                  ? 'Stand at the entrance and tap ➕ to drop the first node.'
                  : '${_nodes.length} node${_nodes.length == 1 ? '' : 's'} mapped'
                      ' · ${_buildEdges().length ~/ 2} edges'
                      ' · Long-press to rename',
              style: const TextStyle(color: Colors.cyanAccent, fontSize: 13),
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
              size: 72, color: Colors.white.withValues(alpha: 0.12)),
          const SizedBox(height: 16),
          const Text('No nodes yet',
              style: TextStyle(color: Colors.white38, fontSize: 16)),
          const SizedBox(height: 6),
          const Text('Walk to a location and tap ➕',
              style: TextStyle(color: Colors.white24, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildNodeTile(int index) {
    final node = _nodes[index];
    final isFirst = index == 0;
    final isLast = index == _nodes.length - 1;
    Color dotColor = Colors.white38;
    if (isFirst) dotColor = Colors.cyanAccent;
    if (isLast && _nodes.length > 1) dotColor = Colors.amberAccent;

    return GestureDetector(
      onLongPress: () => _renameNode(index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: dotColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            // Step dot
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor.withValues(alpha: 0.15),
                border: Border.all(color: dotColor, width: 1.5),
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
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  Text(
                    '(${node.x.toStringAsFixed(2)}, ${node.y.toStringAsFixed(2)}, ${node.z.toStringAsFixed(2)})',
                    style: const TextStyle(color: Colors.white30, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (isFirst)
              const Icon(Icons.door_front_door_rounded,
                  color: Colors.cyanAccent, size: 16),
            if (isLast && _nodes.length > 1)
              const Icon(Icons.flag_rounded,
                  color: Colors.amberAccent, size: 16),
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
                            strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(_saving ? 'Saving…' : '💾 Save Map'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(0, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
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


