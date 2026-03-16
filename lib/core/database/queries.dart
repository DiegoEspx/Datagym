class Queries {
  // Evolución de PR por ejercicio: peso máximo principal por sesión a lo largo del tiempo
  static const String prEvolution = '''
    SELECT ss.date, MAX(s.weight) AS daily_max
    FROM sets s
    JOIN sessions ss ON s.session_id = ss.id
    JOIN session_exercises se ON s.session_exercise_id = se.id
    WHERE se.catalog_id = ?
      AND s.drop_index = 0
    GROUP BY ss.date
    ORDER BY ss.date ASC;
  ''';

  // Volumen total de una sesión (suma todos los pesos incluyendo drops)
  static const String sessionTotalVolume = '''
    SELECT ec.name, SUM(s.weight * s.reps) AS volumen_total
    FROM sets s
    JOIN session_exercises se ON s.session_exercise_id = se.id
    JOIN exercise_catalog ec ON se.catalog_id = ec.id
    WHERE s.session_id = ?
    GROUP BY ec.name;
  ''';

  // Detectar biseries de una sesión (ejercicios con mismo superset_id)
  static const String detectSupersets = '''
    SELECT superset_id, GROUP_CONCAT(ec.name, ' + ') AS ejercicios
    FROM session_exercises se
    JOIN exercise_catalog ec ON se.catalog_id = ec.id
    WHERE se.session_id = ?
      AND se.superset_id IS NOT NULL
    GROUP BY se.superset_id;
  ''';
}
