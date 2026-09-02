import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math_64.dart';
import '../models/pose.dart';
import '../models/node.dart';
import '../services/world_alignment_service.dart';
import '../tracking/position_provider.dart';
import 'ar_arrow.dart';

class ARManager extends ChangeNotifier {
  final PositionProvider positionProvider;
  final WorldAlignmentService alignmentService;
  final ARArrow arrow = ARArrow();

  StreamSubscription<Pose>? _poseSubscription;
  Pose _lastPose = Pose.identity();
  Node? _currentTargetNode;
  bool _isSessionActive = false;

  // Thresholds to avoid unnecessary frame updates (Change #5)
  static const double positionDeltaThreshold = 0.04; // 4 cm
  static const double yawDeltaThreshold = 0.017; // ~1 degree

  ARManager({
    required this.positionProvider,
    required this.alignmentService,
  });

  bool get isSessionActive => _isSessionActive;
  Pose get currentPose => _lastPose;
  Node? get currentTargetNode => _currentTargetNode;

  Future<void> initializeSession() async {
    if (_isSessionActive) return;
    _isSessionActive = true;

    await positionProvider.start();
    _poseSubscription = positionProvider.poseStream.listen(_onPoseReceived);
  }

  void setTargetNode(Node? targetNode) {
    _currentTargetNode = targetNode;
    _updateArrowIfNeeded(force: true);
  }

  void _onPoseReceived(Pose pose) {
    final posDelta = (pose.position - _lastPose.position).length;
    final yawDelta = (pose.yawRadians - _lastPose.yawRadians).abs();

    if (posDelta > positionDeltaThreshold || yawDelta > yawDeltaThreshold || pose.trackingState != _lastPose.trackingState) {
      _lastPose = pose;
      _updateArrowIfNeeded();
    }
  }

  void _updateArrowIfNeeded({bool force = false}) {
    if (_currentTargetNode == null) return;

    final targetWorldPos = alignmentService.transformJsonToWorld(_currentTargetNode!);
    arrow.update(
      cameraPose: _lastPose,
      targetWorldPos: targetWorldPos,
    );
    notifyListeners();
  }

  Future<void> pauseSession() async {
    _isSessionActive = false;
    await _poseSubscription?.cancel();
    _poseSubscription = null;
    await positionProvider.stop();
    notifyListeners();
  }

  @override
  void dispose() {
    pauseSession();
    super.dispose();
  }
}
