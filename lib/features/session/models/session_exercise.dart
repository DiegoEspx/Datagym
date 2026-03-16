class SessionExercise {
  final int? id;
  final int sessionId;
  final int catalogId;
  final int orderIndex;
  final int? supersetId;
  final String? notes;

  SessionExercise({
    this.id,
    required this.sessionId,
    required this.catalogId,
    required this.orderIndex,
    this.supersetId,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'catalog_id': catalogId,
      'order_index': orderIndex,
      'superset_id': supersetId,
      'notes': notes,
    };
  }

  factory SessionExercise.fromMap(Map<String, dynamic> map) {
    return SessionExercise(
      id: map['id'],
      sessionId: map['session_id'],
      catalogId: map['catalog_id'],
      orderIndex: map['order_index'],
      supersetId: map['superset_id'],
      notes: map['notes'],
    );
  }
}
