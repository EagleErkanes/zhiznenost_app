class VisitModel {
  final String id;
  final String clientId;
  final String workoutType;
  final DateTime visitedAt;

  VisitModel({
    required this.id,
    required this.clientId,
    required this.workoutType,
    required this.visitedAt,
  });

  factory VisitModel.fromMap(Map<String, dynamic> map) {
    return VisitModel(
      id: map['id']?.toString() ?? '',
      clientId: map['client_id']?.toString() ?? '',
      workoutType: map['workout_type'] ?? 'Функционална тренировка',
      visitedAt: map['visited_at'] != null
          ? DateTime.parse(map['visited_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'client_id': clientId,
      'workout_type': workoutType,
      'visited_at': visitedAt.toIso8601String(),
    };
  }
}