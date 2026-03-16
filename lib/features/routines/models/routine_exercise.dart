class RoutineExercise {
  final int? id;
  final int routineId;
  final int catalogId;
  final int orderIndex;

  RoutineExercise({
    this.id,
    required this.routineId,
    required this.catalogId,
    required this.orderIndex,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'routine_id': routineId,
      'catalog_id': catalogId,
      'order_index': orderIndex,
    };
  }

  factory RoutineExercise.fromMap(Map<String, dynamic> map) {
    return RoutineExercise(
      id: map['id'],
      routineId: map['routine_id'],
      catalogId: map['catalog_id'],
      orderIndex: map['order_index'],
    );
  }
}
