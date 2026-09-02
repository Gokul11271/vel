import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math_64.dart';
import '../models/node.dart';
import '../models/pose.dart';
import '../models/navigation_state.dart';
import '../algorithms/dijkstra.dart';
import '../services/world_alignment_service.dart';
import '../tracking/position_provider.dart';
import '../tracking/native_ar_position_provider.dart';
import '../tracking/simulation_position_provider.dart';

class NavigationController extends ChangeNotifier {
  final List<Node> path;
  final PositionProvider positionProvider;
  final WorldAlignmentService alignmentService;

  // Adaptive arrival thresholds (Change #6)
  final double waypointArrivalThreshold;
  final double destinationArrivalThreshold;

  int _currentStepIndex = 0;
  NavigationState _state = NavigationState.initializing;
  Pose _latestPose = Pose.identity();
  StreamSubscription<Pose>? _poseSubscription;

  NavigationController({
    required DijkstraResult routeResult,
    required this.positionProvider,
    required this.alignmentService,
    this.waypointArrivalThreshold = 0.8, // 0.8m for intermediate turns
    this.destinationArrivalThreshold = 1.5, // 1.5m for final rooms/doors
  }) : path = routeResult.path {
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

  // Getters
  NavigationState get state => _state;
  int get currentStepIndex => _currentStepIndex;
  Pose get latestPose => _latestPose;
  TrackingState get trackingState => _latestPose.trackingState;
  bool get isFinished => _state == NavigationState.destinationReached;
  bool get isNavigating => _state == NavigationState.navigating;

  Node? get startNode => path.isNotEmpty ? path.first : null;
  Node? get currentNode => path.isNotEmpty && _currentStepIndex < path.length ? path[_currentStepIndex] : null;

  Node? get nextTargetNode {
    if (path.isEmpty || _currentStepIndex >= path.length - 1) return null;
    return path[_currentStepIndex + 1];
  }

  Node? get finalDestination => path.isNotEmpty ? path.last : null;

  /// Distance from current user AR position to next target waypoint
  double get distanceToNextTarget {
    final target = nextTargetNode;
    if (target == null) return 0.0;
    return alignmentService.getDistanceToNode(_latestPose.position, target);
  }

  /// Total remaining distance across all subsequent path legs
  double get totalDistanceRemaining {
    if (isFinished || nextTargetNode == null) return 0.0;

    double dist = distanceToNextTarget;
    for (int i = _currentStepIndex + 1; i < path.length - 1; i++) {
      dist += path[i].distanceTo(path[i + 1]);
    }
    return dist;
  }

  /// Starts calibration state
  void beginCalibration() {
    _state = NavigationState.calibrating;
    notifyListeners();
  }

  /// Completes calibration with the alignment service and transitions to navigating
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

  void _onPoseReceived(Pose pose) {
    _latestPose = pose;

    // Handle tracking state anomalies
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
      _checkWaypointProgression();
    }

    notifyListeners();
  }

  void _checkWaypointProgression() {
    final target = nextTargetNode;
    if (target == null) {
      _state = NavigationState.destinationReached;
      return;
    }

    final isLastWaypoint = _currentStepIndex == path.length - 2;
    final threshold = isLastWaypoint ? destinationArrivalThreshold : waypointArrivalThreshold;

    final dist = alignmentService.getDistanceToNode(_latestPose.position, target);

    if (dist <= threshold) {
      if (isLastWaypoint) {
        _currentStepIndex++;
        _state = NavigationState.destinationReached;
      } else {
        _currentStepIndex++;
        _state = NavigationState.waypointReached;
        // Auto transition back to navigating next frame
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

  /// Simulates stepping along the path when testing on simulator / emulator
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

    final yaw = delta.length2 > 0 ? alignmentService.getBearingToNode(_latestPose.position, target) : _latestPose.yawRadians;

    final simulatedPose = Pose.fromValues(
      x: newPos.x,
      y: newPos.y,
      z: newPos.z,
      yawRadians: yaw,
      trackingState: TrackingState.good,
    );

    if (positionProvider is SimulationPositionProvider) {
      (positionProvider as SimulationPositionProvider).setPosition(
        x: newPos.x,
        y: newPos.y,
        z: newPos.z,
        yawRadians: yaw,
      );
    } else if (positionProvider is NativeArPositionProvider) {
      (positionProvider as NativeArPositionProvider).stepTowards(targetWorld, stepMeters: stepMeters);
    } else {
      _onPoseReceived(simulatedPose);
    }
  }

  /// Manually advances to next waypoint along the path
  void advanceToNextWaypoint() {
    final target = nextTargetNode;
    if (target == null || isFinished) return;

    final targetWorld = alignmentService.transformJsonToWorld(target);
    if (positionProvider is NativeArPositionProvider) {
      (positionProvider as NativeArPositionProvider).setPosition(targetWorld);
    }

    if (_currentStepIndex < path.length - 1) {
      _currentStepIndex++;
      if (_currentStepIndex >= path.length - 1) {
        _state = NavigationState.destinationReached;
      } else {
        _state = NavigationState.navigating;
      }
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
