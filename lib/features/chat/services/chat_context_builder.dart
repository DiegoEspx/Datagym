import '../../../core/database/database_helper.dart';

class ChatContextBuilder {
  static Future<String> buildSystemPrompt() async {
    final db = await DatabaseHelper.instance.database;
    
    // Get last 5 sessions
    final List<Map<String, dynamic>> sessions = await db.query(
      'sessions',
      orderBy: 'date DESC',
      limit: 5,
    );

    StringBuffer context = StringBuffer();
    context.writeln("Eres un asistente de gimnasio experto y motivador llamado DataGym AI.");
    context.writeln("Tu objetivo es analizar los datos del usuario y responder preguntas sobre su progreso.");
    context.writeln("Responde siempre en español, de forma concisa y basada ÚNICAMENTE en los datos proporcionados.");
    context.writeln("");
    context.writeln("Aquí están los datos recientes del usuario:");

    if (sessions.isEmpty) {
      context.writeln("- El usuario aún no ha registrado sesiones.");
    } else {
      for (var session in sessions) {
        context.writeln("\nSesión del ${session['date']}:");
        
        final exercises = await db.rawQuery('''
          SELECT se.id, ec.name 
          FROM session_exercises se
          JOIN exercise_catalog ec ON se.catalog_id = ec.id
          WHERE se.session_id = ?
        ''', [session['id']]);

        for (var ex in exercises) {
          final sets = await db.query('sets', 
            where: 'session_exercise_id = ?', 
            whereArgs: [ex['id']],
            orderBy: 'order_index ASC'
          );
          
          final setsStr = sets.map((s) => "${s['weight']}${s['unit']} x ${s['reps']}").join(", ");
          context.writeln("- ${ex['name']}: [$setsStr]");
        }
      }
    }

    context.writeln("\nInstrucciones adicionales:");
    context.writeln("- Si el usuario pregunta por progreso, busca tendencias de aumento de peso o repeticiones.");
    context.writeln("- Si el peso bajó, sugiere que puede ser fatiga o una variación normal, pero mantén la motivación.");
    context.writeln("- No inventes datos que no estén aquí.");
    
    return context.toString();
  }
}
