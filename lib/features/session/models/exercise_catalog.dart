class ExerciseCatalog {
  final int? id;
  final String name;
  final String nameNormalized;

  ExerciseCatalog({
    this.id,
    required this.name,
    required this.nameNormalized,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'name_normalized': nameNormalized,
    };
  }

  factory ExerciseCatalog.fromMap(Map<String, dynamic> map) {
    return ExerciseCatalog(
      id: map['id'],
      name: map['name'],
      nameNormalized: map['name_normalized'],
    );
  }
}
