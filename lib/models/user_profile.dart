class UserProfile {
  final String id;
  final String email;
  final String fullName;
  final String role; // 'client' или 'coach'
  final String? coachId;
  final String? gender;
  final int? age;
  final double? height;
  final double? weight;
  final String? goal;
  final DateTime? createdAt;

  UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    this.role = 'client',
    this.coachId,
    this.gender,
    this.age,
    this.height,
    this.weight,
    this.goal,
    this.createdAt,
  });

  bool get isCoach => role == 'coach';

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      fullName: map['full_name']?.toString() ?? '',
      role: map['role']?.toString() ?? 'client',
      coachId: map['coach_id']?.toString(),
      gender: map['gender']?.toString(),
      age: map['age'] != null ? int.tryParse(map['age'].toString()) : null,
      height: map['height'] != null ? double.tryParse(map['height'].toString()) : null,
      weight: map['weight'] != null ? double.tryParse(map['weight'].toString()) : null,
      goal: map['goal']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role,
      'coach_id': coachId,
      'gender': gender,
      'age': age,
      'height': height,
      'weight': weight,
      'goal': goal,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? fullName,
    String? role,
    String? coachId,
    String? gender,
    int? age,
    double? height,
    double? weight,
    String? goal,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      coachId: coachId ?? this.coachId,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      goal: goal ?? this.goal,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}