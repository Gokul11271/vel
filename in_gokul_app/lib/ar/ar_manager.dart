import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/pose.dart';
import '../models/node.dart';
import '../models/breadcrumb.dart';
import '../algorithms/route_segment_generator.dart';
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
  List<Breadcrumb> _breadcrumbs = [];
  int _activeSegmentIndex = 0;
  bool _isSessionActive = false;

  // Thresholds to avoid unnecessary frame updates
  static const double positionDeltaThreshold = 0.03; // 3 cm
  static const double yawDeltaThreshold = 0.014;     // ~0.8 degrees

  ARManager({
    required this.positionProvider,
    required this.alignmentService,
  });

  bool get isSessionActive => _isSessionActive;
  Pose get currentPose => _lastPose;
  Node? get currentTargetNode => _currentTargetNode;
  List<Breadcrumb> get breadcrumbs => _breadcrumbs;
  int get activeSegmentIndex => _activeSegmentIndex;

  Future<void> initializeSession() async {
    if (_isSessionActive) return;
    _isSessionActive = true;

    await positionProvider.start();
    _poseSubscription = positionProvider.poseStream.listen(_onPoseReceived);
  }

  /// Sets the active Dijkstra route and generates the 1.2m floor breadcrumbs.
  void setRoute(List<Node> path, {int currentStepIndex = 0}) {
    _activeSegmentIndex = currentStepIndex;
    _breadcrumbs = RouteSegmentGenerator.generateBreadcrumbs(path);
    notifyListeners();
  }

  /// Updates active waypoint target and advances breadcrumb segment.
  void setTargetNode(Node? targetNode, {int currentStepIndex = 0}) {
    _currentTargetNode = targetNode;
    _activeSegmentIndex = currentStepIndex;
    _updateArrowIfNeeded(force: true);
  }

  void _onPoseReceived(Pose pose) {
    final posDelta = (pose.position - _lastPose.position).length;
    final yawDelta = (pose.yawRadians - _lastPose.yawRadians).abs();

    if (posDelta > positionDeltaThreshold ||
        yawDelta > yawDeltaThreshold ||
        pose.trackingState != _lastPose.trackingState) {
      _lastPose = pose;
      _updateArrowIfNeeded();
    }
  }

  bool _isDisposed = false;

  void _updateArrowIfNeeded({bool force = false}) {
    if (_currentTargetNode == null || _isDisposed) return;

    final targetWorldPos =
        alignmentService.transformJsonToWorld(_currentTargetNode!);
    arrow.update(
      cameraPose: _lastPose,
      targetWorldPos: targetWorldPos,
    );
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  Future<void> pauseSession() async {
    _isSessionActive = false;
    await _poseSubscription?.cancel();
    _poseSubscription = null;
    await positionProvider.stop();
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _isSessionActive = false;
    _poseSubscription?.cancel();
    _poseSubscription = null;
    super.dispose();
  }
}
