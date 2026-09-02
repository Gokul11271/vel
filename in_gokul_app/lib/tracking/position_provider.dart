import '../models/pose.dart';

abstract class PositionProvider {
  /// Live stream of 6DOF pose updates
  Stream<Pose> get poseStream;

  /// Most recently reported pose
  Pose get currentPose;

  /// Starts the underlying tracking engine (ARCore / ARKit / Sensors / Sim)
  Future<void> start();

  /// Pauses or stops tracking
  Future<void> stop();

  /// Cleans up resources
  void dispose();
}
