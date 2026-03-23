import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/routine_provider.dart';
import 'routine_edit_screen.dart';
import '../../session/screens/new_session_screen.dart';

class RoutinesListScreen extends ConsumerWidget {
  const RoutinesListScreen({super.key});

  Future<void> _openRoutineEditor(BuildContext context, {dynamic routine}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RoutineEditScreen(routine: routine)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routines = ref.watch(routineProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Rutinas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openRoutineEditor(context),
          ),
        ],
      ),
      body: routines.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No tienes rutinas creadas.'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _openRoutineEditor(context),
                    child: const Text('Crear mi primera rutina'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () => ref.read(routineProvider.notifier).loadRoutines(),
              child: ListView.builder(
                itemCount: routines.length,
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  final routine = routines[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text(routine.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('Creada el ${routine.createdAt.day}/${routine.createdAt.month}/${routine.createdAt.year}'),
                      trailing: const Icon(Icons.more_horiz),
                      onTap: () {
                        _showRoutineOptions(context, ref, routine);
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }

  void _showRoutineOptions(BuildContext context, WidgetRef ref, dynamic routine) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      builder: (sheetCtx) => SafeArea(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.play_arrow, color: Colors.green),
            title: const Text('Iniciar sesión con esta rutina'),
            onTap: () {
              Navigator.pop(sheetCtx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NewSessionScreen(routine: routine),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit, color: Colors.blue),
            title: const Text('Editar rutina'),
            onTap: () {
              Navigator.pop(sheetCtx);
              _openRoutineEditor(context, routine: routine);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
            title: const Text('Eliminar rutina'),
            onTap: () async {
              Navigator.pop(sheetCtx);
              final shouldDelete = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Eliminar rutina'),
                      content: Text('Se eliminará "${routine.name}" y su plantilla de ejercicios.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
                      ],
                    ),
                  ) ??
                  false;
              if (!shouldDelete) return;
              await ref.read(routineProvider.notifier).deleteRoutine(routine.id!);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    ));
  }
}
