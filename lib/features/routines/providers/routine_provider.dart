import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';
import '../models/routine.dart';
import '../../session/models/exercise_catalog.dart';

final routineProvider = StateNotifierProvider<RoutineNotifier, List<Routine>>((ref) {
  return RoutineNotifier();
});

class RoutineNotifier extends StateNotifier<List<Routine>> {
  RoutineNotifier() : super([]) {
    loadRoutines();
  }

  Future<void> loadRoutines() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query('routines', orderBy: 'created_at DESC');
    state = maps.map((map) => Routine.fromMap(map)).toList();
  }

  Future<int> createRoutine(String name, List<dynamic> exercises) async {
    final db = await DatabaseHelper.instance.database;

    final routineId = await db.transaction((txn) async {
      final routineId = await txn.insert('routines', {
        'name': name,
        'created_at': DateTime.now().toIso8601String(),
      });

      for (int i = 0; i < exercises.length; i++) {
        final item = exercises[i];
        final ExerciseCatalog exercise = item is ExerciseCatalog ? item : item['exercise'] as ExerciseCatalog;
        final int? supersetGroup = item is ExerciseCatalog ? null : item['superset_group'] as int?;
        await txn.insert('routine_exercises', {
          'routine_id': routineId,
          'catalog_id': exercise.id,
          'order_index': i + 1,
          'superset_group': supersetGroup,
        });
      }
 
      return routineId;
    });

    await loadRoutines();
    return routineId;
  }

  Future<void> updateRoutine(int routineId, String name, List<dynamic> exercises) async {
    final db = await DatabaseHelper.instance.database;

    await db.transaction((txn) async {
      await txn.update(
        'routines',
        {'name': name},
        where: 'id = ?',
        whereArgs: [routineId],
      );

      await txn.delete('routine_exercises', where: 'routine_id = ?', whereArgs: [routineId]);

      for (int i = 0; i < exercises.length; i++) {
        final item = exercises[i];
        final ExerciseCatalog exercise = item is ExerciseCatalog ? item : item['exercise'] as ExerciseCatalog;
        final int? supersetGroup = item is ExerciseCatalog ? null : item['superset_group'] as int?;
        await txn.insert('routine_exercises', {
          'routine_id': routineId,
          'catalog_id': exercise.id,
          'order_index': i + 1,
          'superset_group': supersetGroup,
        });
      }
    });

    await loadRoutines();
  }

  Future<void> deleteRoutine(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('routines', where: 'id = ?', whereArgs: [id]);
    await loadRoutines();
  }
  
  Future<List<Map<String, dynamic>>> getRoutineExercises(int routineId) async {
    final db = await DatabaseHelper.instance.database;
    return await db.rawQuery('''
      SELECT ec.*, re.order_index, re.superset_group 
      FROM exercise_catalog ec
      JOIN routine_exercises re ON ec.id = re.catalog_id
      WHERE re.routine_id = ?
      ORDER BY re.order_index ASC
    ''', [routineId]);
  }
}
