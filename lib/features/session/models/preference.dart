class Preference {
  final String key;
  final String value;

  Preference({
    required this.key,
    required this.value,
  });

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'value': value,
    };
  }

  factory Preference.fromMap(Map<String, dynamic> map) {
    return Preference(
      key: map['key'],
      value: map['value'],
    );
  }
}
