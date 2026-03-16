class GymSet {
  final int? id;
  final int sessionExerciseId;
  final int sessionId;
  final int orderIndex;
  final int setNumber;
  final int dropIndex;
  final double weight;
  final String unit;
  final int reps;

  GymSet({
    this.id,
    required this.sessionExerciseId,
    required this.sessionId,
    required this.orderIndex,
    required this.setNumber,
    this.dropIndex = 0,
    required this.weight,
    this.unit = 'kg',
    required this.reps,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_exercise_id': sessionExerciseId,
      'session_id': sessionId,
      'order_index': orderIndex,
      'set_number': setNumber,
      'drop_index': dropIndex,
      'weight': weight,
      'unit': unit,
      'reps': reps,
    };
  }

  factory GymSet.fromMap(Map<String, dynamic> map) {
    return GymSet(
      id: map['id'],
      sessionExerciseId: map['session_exercise_id'],
      sessionId: map['session_id'],
      orderIndex: map['order_index'],
      setNumber: map['set_number'],
      dropIndex: map['drop_index'],
      weight: (map['weight'] as num).toDouble(),
      unit: map['unit'],
      reps: map['reps'],
    );
  }
}
