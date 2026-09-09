enum ARTrackingState {
  initializing,
  tracking,
  paused,
  stopped,
  error,
}

extension ARTrackingStateX on ARTrackingState {
  static ARTrackingState fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'TRACKING':
        return ARTrackingState.tracking;
      case 'PAUSED':
        return ARTrackingState.paused;
      case 'STOPPED':
        return ARTrackingState.stopped;
      case 'INITIALIZING':
        return ARTrackingState.initializing;
      default:
        return ARTrackingState.error;
    }
  }

  String get displayName {
    switch (this) {
      case ARTrackingState.tracking:
        return 'Tracking';
      case ARTrackingState.paused:
        return 'Paused';
      case ARTrackingState.stopped:
        return 'Stopped';
      case ARTrackingState.initializing:
        return 'Initializing';
      case ARTrackingState.error:
        return 'Error / Unsupported';
    }
  }
}
