class Edge {
  final int sourceId;
  final int targetId;
  final double weight;

  Edge({
    required this.sourceId,
    required this.targetId,
    required this.weight,
  });

  factory Edge.fromJson(Map<String, dynamic> json) {
    return Edge(
      sourceId: json['sourceId'] as int,
      targetId: json['targetId'] as int,
      weight: (json['weight'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sourceId': sourceId,
      'targetId': targetId,
      'weight': weight,
    };
  }

  @override
  String toString() => 'Edge($sourceId -> $targetId, weight: ${weight.toStringAsFixed(2)})';
}
