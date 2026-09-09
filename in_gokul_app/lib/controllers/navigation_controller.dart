import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math_64.dart';
import '../models/graph.dart';
import '../models/node.dart';
import '../models/pose.dart';
import '../models/navigation_state.dart';
import '../algorithms/dijkstra.dart';
import '../algorithms/map_matcher.dart';
import '../services/world_alignment_service.dart';
import '../tracking/position_provider.dart';
import '../tracking/native_ar_position_provider.dart';
import '../tracking/simulation_position_provider.dart';

class NavigationController extends ChangeNotifier {
  List<Node> path;
  final PositionProvider positionProvider;
  final WorldAlignmentService alignmentService;

  // ── Corridor & Arrival thresholds ──────────────────────────────────────────
  /// Total width of the hallway/corridor in meters (half-width tolerance from centerline).
  final double corridorWidthM;

  /// Distance to auto-advance past an intermediate waypoint (meters).
  final double waypointArrivalThreshold;

  /// Distance to declare "destination reached" for the final node (meters).
  final double destinationArrivalThreshold;

  // ── Off-route detection ─────────────────────────────────────────────────────
  /// Maximum deviation beyond corridor bounds before considering off-route.
  static const double _offRouteThresholdM = 3.5;

  /// Number of consecutive pose readings beyond threshold before recalculating.
  static const int _offRouteFrameLimit = 12;
  int _offRouteFrames = 0;

  // ── State ───────────────────────────────────────────────────────────────────
  int _currentStepIndex = 0;
  NavigationState _state = NavigationState.initializing;

  /// Raw 6DOF sensor pose (used strictly for camera orientation & viewport rendering).
  Pose _latestPose = Pose.identity();
  StreamSubscription<Pose>? _poseSubscription;

  /// Snapped position from map-matching (JSON coordinate space).
  /// Used for distance / Dijkstra / waypoint logic.
  Vector3 _snappedJsonPosition = Vector3.zero();
  bool _hasSnappedOnce = false;

  /// Whether current user position is within acceptable corridor bounds.
  bool _isInsideCorridor = true;
  double _distanceToCorridorCenterline = 0.0;

  /// Number of consecutive frames required at arrival threshold before advancing.
  final int arrivalFrameThreshold;

  /// Optional graph for re-routing. Set after construction or in constructor.
  Graph? graph;

  /// Fires when the controller auto-recalculates a new route.
  VoidCallback? onRouteRecalculated;

  NavigationController({
    required DijkstraResult routeResult,
    required this.positionProvider,
    required this.alignmentService,
    this.corridorWidthM = MapMatcher.defaultCorridorWidthM,
    this.waypointArrivalThreshold = 1.8,
    this.destinationArrivalThreshold = 1.5,
    this.arrivalFrameThreshold = 3,
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

  // ── Getters: Decoupled Poses ────────────────────────────────────────────────

  /// Raw sensor pose (for smooth camera matrices and viewport rotation).
  Pose get rawPose => _latestPose;

  /// Aliased for backward compatibility with existing HUD callers.
  Pose get latestPose => _latestPose;

  /// Corridor-snapped JSON position.
  Vector3? get snappedJsonPosition => _snappedJsonPosition;

  /// Corridor-snapped navigation pose (for waypoint progression & distance calculations).
  Pose get navigationPose {
    return Pose(
      position: snappedWorldPosition,
      rotation: _latestPose.rotation,
      timestamp: _latestPose.timestamp,
      trackingState: _latestPose.trackingState,
    );
  }

  NavigationState get state => _state;
  int get currentStepIndex => _currentStepIndex;
  TrackingState get trackingState => _latestPose.trackingState;
  bool get isFinished => _state == NavigationState.destinationReached;
  bool get isNavigating => _state == NavigationState.navigating;
  bool get isInsideCorridor => _isInsideCorridor;
  double get distanceToCorridorCenterline => _distanceToCorridorCenterline;

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

  /// Snapped position in AR World coordinates.
  Vector3 get snappedWorldPosition {
    if (!_hasSnappedOnce || startNode == null) {
      return _latestPose.position;
    }
    return alignmentService.transformJsonToWorld(
      Node(
        id: -1,
        name: '_snapped',
        x: _snappedJsonPosition.x,
        y: _snappedJsonPosition.y,
        z: _snappedJsonPosition.z,
      ),
    );
  }

  /// 3D distance from current AR position to next waypoint.
  double get distanceToNextTarget {
    final target = nextTargetNode;
    if (target == null) return 0.0;
    return alignmentService.getDistanceToNode(snappedWorldPosition, target);
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

    // ── Map matching: project raw position onto active path / graph ─────────
    final rawJsonPos = alignmentService.transformWorldToJson(pose.position);

    MapMatchResult? matchResult = MapMatcher.projectOntoPath(
      rawJsonPos,
      path,
      corridorWidthM: corridorWidthM,
    );

    if (matchResult == null && graph != null) {
      matchResult = MapMatcher.project(
        rawJsonPos,
        graph!,
        corridorWidthM: corridorWidthM,
      );
    }

    if (matchResult != null) {
      _distanceToCorridorCenterline = matchResult.distanceToEdge;
      _isInsideCorridor = matchResult.isWithinCorridor;
      _snappedJsonPosition = matchResult.snappedPosition;
      _hasSnappedOnce = true;
    } else if (!_hasSnappedOnce) {
      _snappedJsonPosition = rawJsonPos;
    }

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

    if (_state == NavigationState.navigating || _state == NavigationState.waypointReached) {
      if (_state == NavigationState.waypointReached) {
        _state = NavigationState.navigating;
      }
      // Check waypoint progression with segment progress and frame debounce
      _checkWaypointProgression();

      // Off-route detection and auto-reroute
      _checkOffRoute();
    }

    notifyListeners();
  }

  int _consecutiveArrivalFrames = 0;
  int get consecutiveArrivalFrames => _consecutiveArrivalFrames;

  /// Calculates orthogonal projection progress t along segment A -> B.
  /// t = 0.0 means at start node A, t = 1.0 means at target node B.
  double calculateSegmentProgress(Vector3 userJsonPos, Node a, Node b) {
    final dx = b.x - a.x;
    final dz = b.z - a.z;
    final lenSq = dx * dx + dz * dz;
    if (lenSq < 1e-4) return 1.0;
    return (((userJsonPos.x - a.x) * dx) + ((userJsonPos.z - a.z) * dz)) / lenSq;
  }

  /// Current segment progress t along active corridor leg [0.0 to 1.0].
  double get currentSegmentProgress {
    final start = currentNode;
    final target = nextTargetNode;
    if (start == null || target == null) return 1.0;
    final rawJsonPos = alignmentService.transformWorldToJson(_latestPose.position);
    return calculateSegmentProgress(rawJsonPos, start, target);
  }

  void _checkWaypointProgression() {
    if (path.isEmpty || _currentStepIndex >= path.length - 1) return;

    final start = currentNode;
    final target = nextTargetNode;
    if (start == null || target == null) return;

    final isLastLeg = (_currentStepIndex == path.length - 2);
    final rawJsonPos = alignmentService.transformWorldToJson(_latestPose.position);
    final progress = calculateSegmentProgress(rawJsonPos, start, target);
    final effectivePos = snappedWorldPosition;
    final dist = alignmentService.getDistanceToNode(effectivePos, target);

    final threshold = isLastLeg ? destinationArrivalThreshold : waypointArrivalThreshold;
    final isCloseEnough = dist <= threshold;
    final hasProgressed = progress >= 0.75;

    // Advance waypoint if either user is physically close to target node or has walked the segment and is near the turn
    final canAdvance = isCloseEnough || (hasProgressed && dist <= threshold * 1.3);

    if (canAdvance) {
      _consecutiveArrivalFrames++;
      if (_consecutiveArrivalFrames >= arrivalFrameThreshold) {
        _consecutiveArrivalFrames = 0;
        _currentStepIndex++;
        _offRouteFrames = 0;

        if (_currentStepIndex >= path.length - 1) {
          _state = NavigationState.destinationReached;
        } else {
          _state = NavigationState.waypointReached;
          Future.delayed(const Duration(milliseconds: 600), () {
            if (_state == NavigationState.waypointReached) {
              _state = NavigationState.navigating;
              notifyListeners();
            }
          });
        }
        notifyListeners();
      }
    } else {
      if (_consecutiveArrivalFrames > 0) {
        _consecutiveArrivalFrames--;
      }
    }
  }

  /// Detects if the user is drifting away from the planned route and
  /// triggers a Dijkstra recalculation from the nearest graph node.
  void _checkOffRoute() {
    final target = nextTargetNode;
    if (target == null || graph == null) return;

    final effectivePos = snappedWorldPosition;
    final distToNext =
        alignmentService.getDistanceToNode(effectivePos, target);

    // If user is outside the corridor beyond offRouteThresholdM
    if (!_isInsideCorridor && _distanceToCorridorCenterline > _offRouteThresholdM && distToNext > _offRouteThresholdM) {
      _offRouteFrames++;
      if (_offRouteFrames >= _offRouteFrameLimit) {
        _offRouteFrames = 0;
        _recalculateRoute();
      }
    } else {
      if (_offRouteFrames > 0) _offRouteFrames--;
    }
  }

  /// Finds the nearest graph node to current position and recalculates
  /// the Dijkstra path from there to the final destination.
  void _recalculateRoute() {
    final g = graph;
    if (g == null || path.isEmpty) return;

    final destination = path.last;
    // Always use actual raw physical position to determine where user currently is
    final rawJsonPos = alignmentService.transformWorldToJson(_latestPose.position);

    final nearest = MapMatcher.nearestNode(rawJsonPos, g);

    if (nearest == null || nearest.id == destination.id) return;

    final result = Dijkstra.findShortestPath(g, nearest.id, destination.id);

    if (result.path.isEmpty) return;

    path = List.from(result.path);
    _currentStepIndex = 0;
    _offRouteFrames = 0;
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
