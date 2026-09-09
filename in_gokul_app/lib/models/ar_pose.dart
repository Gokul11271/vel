class Vector3D {
  final double x;
  final double y;
  final double z;

  const Vector3D({this.x = 0.0, this.y = 0.0, this.z = 0.0});

  factory Vector3D.fromJson(Map<String, dynamic> json) {
    return Vector3D(
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      z: (json['z'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, double> toJson() => {'x': x, 'y': y, 'z': z};

  @override
  String toString() => 'Vector3D(x: ${x.toStringAsFixed(2)}, y: ${y.toStringAsFixed(2)}, z: ${z.toStringAsFixed(2)})';
}

class Quaternion4D {
  final double x;
  final double y;
  final double z;
  final double w;

  const Quaternion4D({this.x = 0.0, this.y = 0.0, this.z = 0.0, this.w = 1.0});

  factory Quaternion4D.fromJson(Map<String, dynamic> json) {
    return Quaternion4D(
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      z: (json['z'] as num?)?.toDouble() ?? 0.0,
      w: (json['w'] as num?)?.toDouble() ?? 1.0,
    );
  }

  Map<String, double> toJson() => {'x': x, 'y': y, 'z': z, 'w': w};
}

class ARPose {
  final Vector3D position;
  final Quaternion4D rotation;
  final String trackingState;
  final int timestamp;
  final bool isMarkerPlaced;

  const ARPose({
    this.position = const Vector3D(),
    this.rotation = const Quaternion4D(),
    this.trackingState = 'STOPPED',
    this.timestamp = 0,
    this.isMarkerPlaced = false,
  });

  factory ARPose.fromJson(Map<String, dynamic> json) {
    return ARPose(
      position: json['position'] != null
          ? Vector3D.fromJson(Map<String, dynamic>.from(json['position'] as Map))
          : const Vector3D(),
      rotation: json['rotation'] != null
          ? Quaternion4D.fromJson(Map<String, dynamic>.from(json['rotation'] as Map))
          : const Quaternion4D(),
      trackingState: json['trackingState'] as String? ?? 'STOPPED',
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
      isMarkerPlaced: json['isMarkerPlaced'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'position': position.toJson(),
        'rotation': rotation.toJson(),
        'trackingState': trackingState,
        'timestamp': timestamp,
        'isMarkerPlaced': isMarkerPlaced,
      };
}
