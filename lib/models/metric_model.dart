class MetricModel {
  final String id;
  final String clientId;
  final double? weight;
  final int? fatigueLevel;
  final int? painLevel;
  final String? personalRecordExercise;
  final String? personalRecordValue;
  final DateTime recordedAt;

  MetricModel({
    required this.id,
    required this.clientId,
    this.weight,
    this.fatigueLevel,
    this.painLevel,
    this.personalRecordExercise,
    this.personalRecordValue,
    required this.recordedAt,
  });

  factory MetricModel.fromMap(Map<String, dynamic> map) {
    return MetricModel(
      id: map['id'] ?? '',
      clientId: map['client_id'] ?? '',
      weight: (map['weight'] as num?)?.toDouble(),
      fatigueLevel: map['fatigue_level'],
      painLevel: map['pain_level'],
      personalRecordExercise: map['personal_record_exercise'],
      personalRecordValue: map['personal_record_value'],
      recordedAt: DateTime.parse(map['recorded_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'client_id': clientId,
      'weight': weight,
      'fatigue_level': fatigueLevel,
      'pain_level': painLevel,
      'personal_record_exercise': personalRecordExercise,
      'personal_record_value': personalRecordValue,
    };
  }
}