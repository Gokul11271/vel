import 'dart:math';

class Node {
  final int id;
  final String name;
  final double x;
  final double y;
  final double z;

  Node({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    required this.z,
  });

  factory Node.fromJson(Map<String, dynamic> json) {
    return Node(
      id: json['id'] as int,
      name: json['name'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      z: (json['z'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'x': x,
      'y': y,
      'z': z,
    };
  }

  /// Calculates 3D Euclidean distance to another node
  double distanceTo(Node other) {
    final dx = x - other.x;
    final dy = y - other.y;
    final dz = z - other.z;
    return sqrt(dx * dx + dy * dy + dz * dz);
  }

  @override
  String toString() => 'Node($id, $name, x: $x, y: $y, z: $z)';
}
