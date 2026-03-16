import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';
import '../models/session.dart';
import '../models/exercise_catalog.dart';

final sessionProvider = StateNotifierProvider<SessionNotifier, AsyncValue<List<Session>>>((ref) {
  return SessionNotifier();
});

class SessionNotifier extends StateNotifier<AsyncValue<List<Session>>> {
  SessionNotifier() : super(const AsyncValue.loading()) {
    loadSessions();
  }

  Future<void> loadSessions() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final List<Map<String, dynamic>> maps = await db.query('sessions', orderBy: 'date DESC, created_at DESC');
      state = AsyncValue.data(maps.map((map) => Session.fromMap(map)).toList());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<int> saveSession({
    required String date,
    int? routineId,
    String? notes,
    required List<Map<String, dynamic>> exercisesWithSets,
  }) async {
    final db = await DatabaseHelper.instance.database;

    final sessionId = await db.transaction((txn) async {
      final sessionId = await txn.insert('sessions', {
        'routine_id': routineId,
        'date': date,
        'created_at': DateTime.now().toIso8601String(),
        'notes': notes,
      });

      for (int exIndex = 0; exIndex < exercisesWithSets.length; exIndex++) {
        final ex = exercisesWithSets[exIndex];
        final sessionExerciseId = await txn.insert('session_exercises', {
          'session_id': sessionId,
          'catalog_id': ex['catalog_id'],
          'order_index': exIndex + 1,
          'superset_id': ex['superset_id'],
          'notes': ex['notes'],
        });

        final sets = ex['sets'] as List;
        for (int i = 0; i < sets.length; i++) {
          final s = sets[i];
          await txn.insert('sets', {
            'session_exercise_id': sessionExerciseId,
            'session_id': sessionId,
            'order_index': i + 1,
            'set_number': s['set_number'],
            'drop_index': s['drop_index'] ?? 0,
            'weight': s['weight'],
            'unit': s['unit'] ?? 'kg',
            'reps': s['reps'],
          });
        }
      }

      return sessionId;
    });

    await loadSessions();
    return sessionId;
  }

  Future<List<Map<String, dynamic>>> getSessionDetails(int sessionId) async {
    final db = await DatabaseHelper.instance.database;
    final exercises = await db.rawQuery('''
      SELECT se.id, se.superset_id, se.order_index, se.notes, ec.name 
      FROM session_exercises se
      JOIN exercise_catalog ec ON se.catalog_id = ec.id
      WHERE se.session_id = ?
      ORDER BY se.order_index ASC
    ''', [sessionId]);

    List<Map<String, dynamic>> result = [];
    for (var ex in exercises) {
      final sets = await db.query('sets', 
        where: 'session_exercise_id = ?', 
        whereArgs: [ex['id']],
        orderBy: 'order_index ASC'
      );
      var exMap = Map<String, dynamic>.from(ex);
      exMap['sets'] = sets;
      result.add(exMap);
    }
    return result;
  }

  Future<void> deleteSession(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('sessions', where: 'id = ?', whereArgs: [id]);
    await loadSessions();
  }

  Future<List<ExerciseCatalog>> getCatalogExercises() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('exercise_catalog', orderBy: 'name_normalized ASC');
    return maps.map((map) => ExerciseCatalog.fromMap(map)).toList();
  }

  Future<void> deleteFromCatalog(int id) async {
    final db = await DatabaseHelper.instance.database;

    final refs = await db.rawQuery('''
      SELECT COUNT(*) as total
      FROM session_exercises
      WHERE catalog_id = ?
    ''', [id]);

    final total = (refs.first['total'] as num?)?.toInt() ?? 0;

    if (total > 0) {
      throw Exception(
        'Este ejercicio tiene $total registro(s) en tu historial y no puede eliminarse para proteger tus datos.',
      );
    }

    final routineRefs = await db.rawQuery('''
      SELECT COUNT(*) as total
      FROM routine_exercises
      WHERE catalog_id = ?
    ''', [id]);

    final routineTotal = (routineRefs.first['total'] as num?)?.toInt() ?? 0;

    if (routineTotal > 0) {
      throw Exception(
        'Este ejercicio está en $routineTotal rutina(s) guardada(s) y no puede eliminarse. Quítalo de las rutinas primero.',
      );
    }

    await db.delete(
      'exercise_catalog',
      where: 'id = ?',
      whereArgs: [id],
    );

    await getCatalogExercises();
  }

  // Helper for Catalog
  Future<int> getOrCreateCatalogItem(String name) async {
    final db = await DatabaseHelper.instance.database;
    final normalized = name.toLowerCase().trim(); // Basic normalization
    
    final List<Map<String, dynamic>> existing = await db.query(
      'exercise_catalog',
      where: 'name_normalized = ?',
      whereArgs: [normalized]
    );

    if (existing.isNotEmpty) {
      return existing.first['id'] as int;
    } else {
      return await db.insert('exercise_catalog', {
        'name': name.trim(),
        'name_normalized': normalized,
      });
    }
  }

  Future<List<ExerciseCatalog>> searchCatalog(String query) async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'exercise_catalog',
      where: 'name_normalized LIKE ?',
      whereArgs: ['%${query.toLowerCase()}%']
    );
    return maps.map((map) => ExerciseCatalog.fromMap(map)).toList();
  }

  Future<List<Map<String, dynamic>>> getPREvolution(int catalogId) async {
    final db = await DatabaseHelper.instance.database;
    return await db.rawQuery('''
      SELECT ss.date, MAX(s.weight) AS daily_max
      FROM sets s
      JOIN sessions ss ON s.session_id = ss.id
      JOIN session_exercises se ON s.session_exercise_id = se.id
      WHERE se.catalog_id = ?
        AND s.drop_index = 0
      GROUP BY ss.date
      ORDER BY ss.date ASC;
    ''', [catalogId]);
  }

  Future<List<Map<String, dynamic>>> getExerciseHistory(int catalogId) async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> sessions = await db.rawQuery('''
      SELECT ss.date, se.id as session_exercise_id, se.notes
      FROM session_exercises se
      JOIN sessions ss ON se.session_id = ss.id
      WHERE se.catalog_id = ?
      ORDER BY ss.date DESC
    ''', [catalogId]);

    List<Map<String, dynamic>> history = [];
    for (var session in sessions) {
      final sets = await db.query('sets', 
        where: 'session_exercise_id = ?', 
        whereArgs: [session['session_exercise_id']],
        orderBy: 'order_index ASC'
      );
      history.add({
        'date': session['date'],
        'notes': session['notes'],
        'sets': sets,
      });
    }
    return history;
  }
}
