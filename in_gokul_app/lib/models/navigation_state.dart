enum NavigationState {
  initializing,
  waitingForTracking,
  calibrating,
  navigating,
  waypointReached,
  destinationReached,
  trackingLost,
  paused,
}

extension NavigationStateExtension on NavigationState {
  String get displayTitle {
    switch (this) {
      case NavigationState.initializing:
        return 'Initializing System';
      case NavigationState.waitingForTracking:
        return 'Detecting AR Planes';
      case NavigationState.calibrating:
        return 'Aligning with Map';
      case NavigationState.navigating:
        return 'Navigating';
      case NavigationState.waypointReached:
        return 'Waypoint Reached';
      case NavigationState.destinationReached:
        return 'Destination Reached!';
      case NavigationState.trackingLost:
        return 'Tracking Lost';
      case NavigationState.paused:
        return 'Navigation Paused';
    }
  }

  bool get isNavigating => this == NavigationState.navigating || this == NavigationState.waypointReached;
  bool get isFinished => this == NavigationState.destinationReached;
}
