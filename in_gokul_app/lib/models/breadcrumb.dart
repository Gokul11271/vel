import 'package:vector_math/vector_math_64.dart';

/// Represents a discrete 3D spatial waypoint along an interpolated route corridor.
class Breadcrumb {
  /// Sequential index along the path (0, 1, 2, ...).
  final int index;

  /// Spatial position in JSON map coordinates (metres).
  final Vector3 jsonPosition;

  /// Index of the Dijkstra route segment (leg) this breadcrumb belongs to.
  final int segmentIndex;

  /// Unit tangent vector pointing along the forward direction of this segment.
  final Vector3 forwardTangent;

  /// Distance from route origin to this breadcrumb along the path.
  final double distanceAlongPath;

  const Breadcrumb({
    required this.index,
    required this.jsonPosition,
    required this.segmentIndex,
    required this.forwardTangent,
    required this.distanceAlongPath,
  });

  @override
  String toString() =>
      'Breadcrumb(#$index, seg: $segmentIndex, pos: ${jsonPosition.x.toStringAsFixed(1)},${jsonPosition.y.toStringAsFixed(1)},${jsonPosition.z.toStringAsFixed(1)})';
}
