import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math_64.dart';
import '../models/graph.dart';
import '../models/node.dart';
import '../models/pose.dart';
import '../models/navigation_state.dart';
import '../algorithms/dijkstra.dart';
import '../services/world_alignment_service.dart';
import '../tracking/position_provider.dart';
import '../tracking/native_ar_position_provider.dart';
import '../tracking/simulation_position_provider.dart';

class NavigationController extends ChangeNotifier {
  List<Node> path;
  final PositionProvider positionProvider;
  final WorldAlignmentService alignmentService;

  // ── Arrival thresholds ──────────────────────────────────────────────────────
  /// Distance to auto-advance past an intermediate waypoint (meters).
  final double waypointArrivalThreshold;

  /// Distance to declare "destination reached" for the final node (meters).
  final double destinationArrivalThreshold;

  // ── Off-route detection ─────────────────────────────────────────────────────
  /// If the user's distance to the next waypoint exceeds this, consider off-route.
  static const double _offRouteThresholdM = 4.5;

  /// Number of consecutive pose readings beyond threshold before recalculating.
  static const int _offRouteFrameLimit = 20;
  int _offRouteFrames = 0;

  // ── State ───────────────────────────────────────────────────────────────────
  int _currentStepIndex = 0;
  NavigationState _state = NavigationState.initializing;
  Pose _latestPose = Pose.identity();
  StreamSubscription<Pose>? _poseSubscription;

  /// Optional graph for re-routing. Set after construction if you want
  /// off-route Dijkstra recalculation.
  Graph? graph;

  /// Fires when the controller auto-recalculates a new route.
  /// The caller may update UI accordingly.
  VoidCallback? onRouteRecalculated;

  NavigationController({
    required DijkstraResult routeResult,
    required this.positionProvider,
    required this.alignmentService,
    this.waypointArrivalThreshold = 2.0,  // 2.0m for intermediate waypoints
    this.destinationArrivalThreshold = 3.0, // 3.0m for final destination
    this.graph,
    this.onRouteRecalculated,
  }) : path = List.from(routeResult.path) {
    _init();
  }

  void _init() {
    if (path.isEmpty) {
      _state = NavigationState.destinationReached;
      return;
    }
    _state = NavigationState.waitingForTracking;
    _poseSubscription = positionProvider.poseStream.listen(_onPoseReceived);
  }

  // ── Getters ─────────────────────────────────────────────────────────────────

  NavigationState get state => _state;
  int get currentStepIndex => _currentStepIndex;
  Pose get latestPose => _latestPose;
  TrackingState get trackingState => _latestPose.trackingState;
  bool get isFinished => _state == NavigationState.destinationReached;
  bool get isNavigating => _state == NavigationState.navigating;

  Node? get startNode => path.isNotEmpty ? path.first : null;

  Node? get currentNode =>
      path.isNotEmpty && _currentStepIndex < path.length
          ? path[_currentStepIndex]
          : null;

  Node? get nextTargetNode {
    if (path.isEmpty || _currentStepIndex >= path.length - 1) return null;
    return path[_currentStepIndex + 1];
  }

  Node? get finalDestination => path.isNotEmpty ? path.last : null;

  /// 3D distance from current AR position to next waypoint.
  double get distanceToNextTarget {
    final target = nextTargetNode;
    if (target == null) return 0.0;
    return alignmentService.getDistanceToNode(_latestPose.position, target);
  }

  /// Total remaining distance across all path legs ahead.
  double get totalDistanceRemaining {
    if (isFinished || nextTargetNode == null) return 0.0;
    double dist = distanceToNextTarget;
    for (int i = _currentStepIndex + 1; i < path.length - 1; i++) {
      dist += path[i].distanceTo(path[i + 1]);
    }
    return dist;
  }

  // ── Calibration ──────────────────────────────────────────────────────────────

  void beginCalibration() {
    _state = NavigationState.calibrating;
    notifyListeners();
  }

  void completeCalibration() {
    if (startNode == null) return;
    alignmentService.calibrate(
      startNode: startNode!,
      currentPose: _latestPose,
      targetNode: nextTargetNode,
    );
    _state = NavigationState.navigating;
    notifyListeners();
  }

  // ── Pose Handler ────────────────────────────────────────────────────────────

  void _onPoseReceived(Pose pose) {
    _latestPose = pose;

    // Tracking state changes
    if (pose.trackingState == TrackingState.lost) {
      if (_state == NavigationState.navigating) {
        _state = NavigationState.trackingLost;
        notifyListeners();
        return;
      }
    } else if (_state == NavigationState.trackingLost) {
      _state = NavigationState.navigating;
    }

    if (_state == NavigationState.navigating) {
      // 1. Check if user went directly to final destination (skipping nodes)
      _checkDirectDestination();

      // 2. Check normal waypoint progression
      _checkWaypointProgression();

      // 3. Off-route detection
      _checkOffRoute();
    }

    notifyListeners();
  }

  /// Always check proximity to the final destination, regardless of which
  /// step we're on. This fixes the issue where the user arrives at the
  /// destination but hasn't passed all intermediate nodes.
  void _checkDirectDestination() {
    if (path.isEmpty) return;
    final destination = path.last;
    final destDist =
        alignmentService.getDistanceToNode(_latestPose.position, destination);

    if (destDist <= destinationArrivalThreshold) {
      _currentStepIndex = path.length - 1;
      _state = NavigationState.destinationReached;
      notifyListeners();
    }
  }

  void _checkWaypointProgression() {
    final target = nextTargetNode;
    if (target == null) {
      _state = NavigationState.destinationReached;
      return;
    }

    final isLastLeg = _currentStepIndex == path.length - 2;
    final threshold =
        isLastLeg ? destinationArrivalThreshold : waypointArrivalThreshold;
    final dist =
        alignmentService.getDistanceToNode(_latestPose.position, target);

    if (dist <= threshold) {
      _currentStepIndex++;
      _offRouteFrames = 0; // reset off-route counter on progress

      if (_currentStepIndex >= path.length - 1) {
        _state = NavigationState.destinationReached;
      } else {
        _state = NavigationState.waypointReached;
        Future.microtask(() {
          if (_state == NavigationState.waypointReached) {
            _state = NavigationState.navigating;
            notifyListeners();
          }
        });
      }
      notifyListeners();
    }
  }

  /// Detects if the user is drifting away from the planned route and
  /// triggers a Dijkstra recalculation from the nearest graph node.
  void _checkOffRoute() {
    final target = nextTargetNode;
    if (target == null || graph == null) return;

    final distToNext = distanceToNextTarget;

    if (distToNext > _offRouteThresholdM) {
      _offRouteFrames++;
      if (_offRouteFrames >= _offRouteFrameLimit) {
        _offRouteFrames = 0;
        _recalculateRoute();
      }
    } else {
      _offRouteFrames = 0;
    }
  }

  /// Finds the nearest graph node to current position and recalculates
  /// the Dijkstra path from there to the final destination.
  void _recalculateRoute() {
    final g = graph;
    if (g == null || path.isEmpty) return;

    final destination = path.last;
    final currentJsonPos =
        alignmentService.transformWorldToJson(_latestPose.position);

    // Find nearest graph node to current world position
    Node? nearest;
    double nearestDist = double.infinity;
    for (final node in g.nodes.values) {
      final d = (currentJsonPos - Vector3(node.x, node.y, node.z)).length;
      if (d < nearestDist) {
        nearestDist = d;
        nearest = node;
      }
    }

    if (nearest == null || nearest.id == destination.id) return;

    final result =
        Dijkstra.findShortestPath(g, nearest.id, destination.id);

    if (result.path.isEmpty) return;

    // Rebuild path: current step stays, replace remainder with new route
    path = List.from(result.path);
    _currentStepIndex = 0;
    _state = NavigationState.navigating;
    notifyListeners();
    onRouteRecalculated?.call();

    debugPrint('🔄 Route recalculated via ${nearest.name} → ${destination.name}');
  }

  // ── Simulation helpers (for testing) ────────────────────────────────────────

  void simulateStep({double stepMeters = 0.5}) {
    final target = nextTargetNode;
    if (target == null || isFinished) return;

    final targetWorld = alignmentService.transformJsonToWorld(target);
    final delta = targetWorld - _latestPose.position;
    final dist = delta.length;

    Vector3 newPos;
    if (dist <= stepMeters) {
      newPos = targetWorld;
    } else {
      newPos = _latestPose.position + (delta * (stepMeters / dist));
    }
    final yaw = delta.length2 > 0
        ? alignmentService.getBearingToNode(_latestPose.position, target)
        : _latestPose.yawRadians;

    final simPose = Pose.fromValues(
        x: newPos.x,
        y: newPos.y,
        z: newPos.z,
        yawRadians: yaw,
        trackingState: TrackingState.good);

    if (positionProvider is SimulationPositionProvider) {
      (positionProvider as SimulationPositionProvider)
          .setPosition(x: newPos.x, y: newPos.y, z: newPos.z, yawRadians: yaw);
    } else if (positionProvider is NativeArPositionProvider) {
      (positionProvider as NativeArPositionProvider)
          .stepTowards(targetWorld, stepMeters: stepMeters);
    } else {
      _onPoseReceived(simPose);
    }
  }

  void advanceToNextWaypoint() {
    final target = nextTargetNode;
    if (target == null || isFinished) return;
    final targetWorld = alignmentService.transformJsonToWorld(target);
    if (positionProvider is NativeArPositionProvider) {
      (positionProvider as NativeArPositionProvider).setPosition(targetWorld);
    }
    if (_currentStepIndex < path.length - 1) {
      _currentStepIndex++;
      _state = _currentStepIndex >= path.length - 1
          ? NavigationState.destinationReached
          : NavigationState.navigating;
      notifyListeners();
    }
  }

  void pause() {
    if (_state == NavigationState.navigating) {
      _state = NavigationState.paused;
      notifyListeners();
    }
  }

  void resume() {
    if (_state == NavigationState.paused) {
      _state = NavigationState.navigating;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _poseSubscription?.cancel();
    super.dispose();
  }
}
