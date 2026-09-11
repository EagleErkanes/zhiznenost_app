class WorkoutSet {
  final int setNumber;
  final double weight;
  final int reps;
  final int rpe; // Скала от 1 до 10

  WorkoutSet({
    required this.setNumber,
    required this.weight,
    required this.reps,
    required this.rpe,
  });

  factory WorkoutSet.fromMap(Map<String, dynamic> map) {
    return WorkoutSet(
      setNumber: map['set_number'] ?? 1,
      weight: (map['weight'] as num?)?.toDouble() ?? 0.0,
      reps: map['reps'] ?? 0,
      rpe: map['rpe'] ?? 8,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'set_number': setNumber,
      'weight': weight,
      'reps': reps,
      'rpe': rpe,
    };
  }
}

class WorkoutEntry {
  final String id;
  final String clientId;
  final String exerciseName;
  final List<WorkoutSet> sets;
  final String notes;
  final DateTime createdAt;

  WorkoutEntry({
    required this.id,
    required this.clientId,
    required this.exerciseName,
    required this.sets,
    this.notes = '',
    required this.createdAt,
  });

  factory WorkoutEntry.fromMap(Map<String, dynamic> map) {
    final setsList = (map['sets'] as List<dynamic>?)
        ?.map((s) => WorkoutSet.fromMap(s as Map<String, dynamic>))
        .toList() ??
        [];

    return WorkoutEntry(
      id: map['id']?.toString() ?? '',
      clientId: map['client_id']?.toString() ?? '',
      exerciseName: map['exercise_name'] ?? '',
      sets: setsList,
      notes: map['notes'] ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'client_id': clientId,
      'exercise_name': exerciseName,
      'sets': sets.map((s) => s.toMap()).toList(),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }
}