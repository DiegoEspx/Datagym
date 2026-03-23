import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';

class ExcelExportService {
  static Future<String> exportToExcel() async {
    final db = await DatabaseHelper.instance.database;
    final excel = Excel.createExcel();

    // ─── Sheet 1: Ejercicios (Catálogo) ───
    final catalogSheet = excel['Catálogo'];
    catalogSheet.appendRow([
      TextCellValue('ID'),
      TextCellValue('Nombre'),
    ]);
    final catalog = await db.query('exercise_catalog', orderBy: 'id ASC');
    for (final row in catalog) {
      catalogSheet.appendRow([
        IntCellValue(row['id'] as int),
        TextCellValue(row['name'] as String),
      ]);
    }

    // ─── Sheet 2: Rutinas ───
    final routinesSheet = excel['Rutinas'];
    routinesSheet.appendRow([
      TextCellValue('ID'),
      TextCellValue('Nombre'),
      TextCellValue('Creada'),
    ]);
    final routines = await db.query('routines', orderBy: 'id ASC');
    for (final row in routines) {
      routinesSheet.appendRow([
        IntCellValue(row['id'] as int),
        TextCellValue(row['name'] as String),
        TextCellValue(row['created_at'] as String),
      ]);
    }

    // ─── Sheet 3: Rutinas - Ejercicios ───
    final routineExSheet = excel['Rutinas_Ejercicios'];
    routineExSheet.appendRow([
      TextCellValue('Rutina'),
      TextCellValue('Ejercicio'),
      TextCellValue('Orden'),
      TextCellValue('Grupo Superset'),
    ]);
    final routineExercises = await db.rawQuery('''
      SELECT r.name AS routine_name, ec.name AS exercise_name,
             re.order_index, re.superset_group
      FROM routine_exercises re
      JOIN routines r ON re.routine_id = r.id
      JOIN exercise_catalog ec ON re.catalog_id = ec.id
      ORDER BY r.id, re.order_index
    ''');
    for (final row in routineExercises) {
      routineExSheet.appendRow([
        TextCellValue(row['routine_name'] as String),
        TextCellValue(row['exercise_name'] as String),
        IntCellValue(row['order_index'] as int),
        row['superset_group'] != null
            ? IntCellValue(row['superset_group'] as int)
            : TextCellValue(''),
      ]);
    }

    // ─── Sheet 4: Sesiones (Historial completo) ───
    final sessionsSheet = excel['Sesiones'];
    sessionsSheet.appendRow([
      TextCellValue('Fecha'),
      TextCellValue('Ejercicio'),
      TextCellValue('Set'),
      TextCellValue('Peso'),
      TextCellValue('Unidad'),
      TextCellValue('Reps'),
      TextCellValue('Drop'),
      TextCellValue('Notas Sesión'),
      TextCellValue('Notas Ejercicio'),
      TextCellValue('Superset ID'),
    ]);

    final sessionData = await db.rawQuery('''
      SELECT ss.date, ec.name AS exercise_name,
             s.set_number, s.weight, s.unit, s.reps, s.drop_index,
             ss.notes AS session_notes, se.notes AS exercise_notes,
             se.superset_id
      FROM sets s
      JOIN session_exercises se ON s.session_exercise_id = se.id
      JOIN sessions ss ON s.session_id = ss.id
      JOIN exercise_catalog ec ON se.catalog_id = ec.id
      ORDER BY ss.date DESC, se.order_index ASC, s.order_index ASC
    ''');

    for (final row in sessionData) {
      sessionsSheet.appendRow([
        TextCellValue(row['date'] as String),
        TextCellValue(row['exercise_name'] as String),
        IntCellValue(row['set_number'] as int),
        DoubleCellValue((row['weight'] as num).toDouble()),
        TextCellValue(row['unit'] as String),
        IntCellValue(row['reps'] as int),
        IntCellValue(row['drop_index'] as int),
        TextCellValue((row['session_notes'] as String?) ?? ''),
        TextCellValue((row['exercise_notes'] as String?) ?? ''),
        row['superset_id'] != null
            ? IntCellValue(row['superset_id'] as int)
            : TextCellValue(''),
      ]);
    }

    // Remove default Sheet1
    excel.delete('Sheet1');

    // Save to file
    final dir = await getApplicationDocumentsDirectory();
    final now = DateTime.now();
    final fileName = 'DataGym_Backup_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.xlsx';
    final filePath = '${dir.path}/$fileName';
    
    final fileBytes = excel.save();
    if (fileBytes == null) throw Exception('No se pudo generar el archivo Excel.');
    
    final file = File(filePath);
    await file.writeAsBytes(fileBytes);

    return filePath;
  }

  static Future<void> exportAndShare() async {
    final filePath = await exportToExcel();
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath)],
        subject: 'DataGym - Backup de datos',
      ),
    );
  }
}
