class Session {
  final int? id;
  final int? routineId;
  final String date;
  final DateTime createdAt;
  final String? notes;

  Session({
    this.id,
    this.routineId,
    required this.date,
    required this.createdAt,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'routine_id': routineId,
      'date': date,
      'created_at': createdAt.toIso8601String(),
      'notes': notes,
    };
  }

  factory Session.fromMap(Map<String, dynamic> map) {
    return Session(
      id: map['id'],
      routineId: map['routine_id'],
      date: map['date'],
      createdAt: DateTime.parse(map['created_at']),
      notes: map['notes'],
    );
  }
}
