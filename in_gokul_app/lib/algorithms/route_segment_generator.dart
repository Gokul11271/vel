import 'package:vector_math/vector_math_64.dart';
import '../models/node.dart';
import '../models/breadcrumb.dart';

/// Interpolates a coarse Dijkstra route (Node -> Node) into a dense sequence
/// of spatial breadcrumbs (every 1.0m to 1.5m).
///
/// This serves as the single source of truth for all renderers:
/// - 2D / 3D Canvas Perspective Projector (Flutter)
/// - Native ARCore / ARKit Surface Plane Anchors (Native Phase 5)
class RouteSegmentGenerator {
  /// Default spacing between floor breadcrumbs (1.0 metres).
  static const double defaultSpacingM = 1.0;

  /// Generates an interpolated sequence of [Breadcrumb] points along [path].
  static List<Breadcrumb> generateBreadcrumbs(
    List<Node> path, {
    double spacingM = defaultSpacingM,
  }) {
    if (path.length < 2) return [];

    final breadcrumbs = <Breadcrumb>[];
    int globalIndex = 0;
    double cumulativeDist = 0.0;

    for (int seg = 0; seg < path.length - 1; seg++) {
      final n1 = path[seg];
      final n2 = path[seg + 1];

      final p1 = Vector3(n1.x, n1.y, n1.z);
      final p2 = Vector3(n2.x, n2.y, n2.z);

      final delta = p2 - p1;
      final legLen = delta.length;
      if (legLen < 1e-4) continue;

      final tangent = delta / legLen;
      final numSteps = (legLen / spacingM).floor();

      for (int i = 0; i <= numSteps; i++) {
        final distOnLeg = i * spacingM;
        if (distOnLeg > legLen) break;

        final pos = p1 + tangent * distOnLeg;
        breadcrumbs.add(
          Breadcrumb(
            index: globalIndex++,
            jsonPosition: pos,
            segmentIndex: seg,
            forwardTangent: tangent,
            distanceAlongPath: cumulativeDist + distOnLeg,
          ),
        );
      }

      cumulativeDist += legLen;
    }

    // Ensure final destination node is included as the terminal breadcrumb
    if (path.isNotEmpty) {
      final lastNode = path.last;
      final lastPos = Vector3(lastNode.x, lastNode.y, lastNode.z);
      if (breadcrumbs.isEmpty ||
          (breadcrumbs.last.jsonPosition - lastPos).length > 0.4) {
        final prevPos = breadcrumbs.isNotEmpty
            ? breadcrumbs.last.jsonPosition
            : lastPos;
        final delta = lastPos - prevPos;
        final tangent = delta.length > 1e-4 ? delta.normalized() : Vector3(0, 0, -1);
        breadcrumbs.add(
          Breadcrumb(
            index: globalIndex++,
            jsonPosition: lastPos,
            segmentIndex: path.length - 2 >= 0 ? path.length - 2 : 0,
            forwardTangent: tangent,
            distanceAlongPath: cumulativeDist,
          ),
        );
      }
    }

    return breadcrumbs;
  }
}
