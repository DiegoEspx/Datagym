import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/routine_provider.dart';
import '../models/routine.dart';
import '../../session/models/exercise_catalog.dart';
import '../../session/providers/session_provider.dart';

class RoutineEditScreen extends ConsumerStatefulWidget {
  final Routine? routine;
  const RoutineEditScreen({super.key, this.routine});

  @override
  ConsumerState<RoutineEditScreen> createState() => _RoutineEditScreenState();
}

class _RoutineEditScreenState extends ConsumerState<RoutineEditScreen> {
  final _nameController = TextEditingController();
  final List<Map<String, dynamic>> _selectedExercises = [];
  bool _isLoading = false;

  void _unlinkSupersetGroup(int? groupId) {
    if (groupId == null) return;
    for (final item in _selectedExercises) {
      if (item['superset_group'] == groupId) {
        item['superset_group'] = null;
      }
    }
  }

  int _nextSupersetGroupId() {
    int maxId = 0;
    for (final item in _selectedExercises) {
      final group = item['superset_group'];
      if (group is int && group > maxId) {
        maxId = group;
      }
    }
    return maxId + 1;
  }

  Future<void> _showSupersetSelector(int exIndex) async {
    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      builder: (sheetCtx) {
        final currentGroup = _selectedExercises[exIndex]['superset_group'] as int?;
        final candidates = <MapEntry<int, Map<String, dynamic>>>[];
        for (int i = 0; i < _selectedExercises.length; i++) {
          if (i != exIndex) {
            candidates.add(MapEntry(i, _selectedExercises[i]));
          }
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Vincular biserie',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 12),
                if (currentGroup != null)
                  ListTile(
                    leading: const Icon(Icons.link_off),
                    title: const Text('Desvincular'),
                    onTap: () {
                      setState(() => _unlinkSupersetGroup(currentGroup));
                      Navigator.pop(sheetCtx);
                    },
                  ),
                if (candidates.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Agrega otro ejercicio para crear una biserie.'),
                    ),
                  )
                else
                  ...candidates.map((entry) {
                    final ex = entry.value['exercise'] as ExerciseCatalog;
                    return ListTile(
                      leading: const Icon(Icons.fitness_center),
                      title: Text(ex.name),
                      onTap: () {
                        final linkedIndex = entry.key;
                        final linkedGroup = _selectedExercises[linkedIndex]['superset_group'] as int?;
                        final newGroup = _nextSupersetGroupId();

                        setState(() {
                          _unlinkSupersetGroup(currentGroup);
                          _unlinkSupersetGroup(linkedGroup);
                          _selectedExercises[exIndex]['superset_group'] = newGroup;
                          _selectedExercises[linkedIndex]['superset_group'] = newGroup;
                        });
                        Navigator.pop(sheetCtx);
                      },
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.routine != null) {
      _nameController.text = widget.routine!.name;
      _loadRoutineExercises();
    }
  }

  Future<void> _loadRoutineExercises() async {
    final exercises = await ref.read(routineProvider.notifier).getRoutineExercises(widget.routine!.id!);
    if (!mounted) return;
    setState(() {
      _selectedExercises.addAll(
        exercises.map(
          (e) => {
            'exercise': ExerciseCatalog.fromMap(e),
            'superset_group': e['superset_group'] as int?,
          },
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.routine == null ? 'Nueva Rutina' : 'Editar Rutina'),
        actions: [
          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(strokeWidth: 2)))
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveRoutine,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la rutina',
                    hintText: 'Ej: Día de Pecho',
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Ejercicios', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                FilledButton.icon(
                  onPressed: _addExercise,
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _selectedExercises.isEmpty
                ? const Center(child: Text('Agrega ejercicios para construir tu rutina.'))
                : ReorderableListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = _selectedExercises.removeAt(oldIndex);
                        _selectedExercises.insert(newIndex, item);
                      });
                    },
                    children: _selectedExercises.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      final ex = item['exercise'] as ExerciseCatalog;
                      final group = item['superset_group'] as int?;
                      final nextGroup = index + 1 < _selectedExercises.length
                          ? _selectedExercises[index + 1]['superset_group'] as int?
                          : null;
                      return Column(
                        key: ValueKey('${ex.id}_$index'),
                        children: [
                          Card(
                            child: ListTile(
                              leading: CircleAvatar(child: Text('${index + 1}')),
                              title: Text(ex.name),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.link),
                                    onPressed: () => _showSupersetSelector(index),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                                    onPressed: () => setState(() {
                                      final removedGroup = _selectedExercises[index]['superset_group'] as int?;
                                      _selectedExercises.removeAt(index);
                                      _unlinkSupersetGroup(removedGroup);
                                    }),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (group != null && group == nextGroup)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Chip(label: Text('Biserie')),
                            ),
                        ],
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  void _addExercise() {
    final searchController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return SafeArea(
              child: Container(
                height: MediaQuery.of(context).size.height * 0.7,
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                children: [
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Nombre del ejercicio...',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () async {
                          if (searchController.text.isNotEmpty) {
                            final ctx = context;
                            final id = await ref.read(sessionProvider.notifier).getOrCreateCatalogItem(searchController.text);
                            final newItem = ExerciseCatalog(id: id, name: searchController.text, nameNormalized: searchController.text.toLowerCase());
                            if (!ctx.mounted) return;
                            setState(() {
                              final alreadyAdded = _selectedExercises.any((e) => (e['exercise'] as ExerciseCatalog).id == newItem.id);
                              if (!alreadyAdded) {
                                _selectedExercises.add({'exercise': newItem, 'superset_group': null});
                              }
                            });
                            Navigator.pop(ctx);
                          }
                        },
                      ),
                    ),
                    onChanged: (val) => setModalState(() {}),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: FutureBuilder<List<ExerciseCatalog>>(
                      future: ref.read(sessionProvider.notifier).searchCatalog(searchController.text),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                        final items = snapshot.data!;
                        return ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (ctx, i) => ListTile(
                            title: Text(items[i].name),
                            onTap: () {
                              setState(() {
                                final alreadyAdded = _selectedExercises.any((e) => (e['exercise'] as ExerciseCatalog).id == items[i].id);
                                if (!alreadyAdded) {
                                  _selectedExercises.add({'exercise': items[i], 'superset_group': null});
                                }
                              });
                              Navigator.pop(context);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ));
          }
        );
      },
    );
  }

  Future<void> _saveRoutine() async {
    if (_nameController.text.isEmpty || _selectedExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor ingresa un nombre y al menos un ejercicio.')));
      return;
    }

    setState(() => _isLoading = true);
    if (widget.routine == null) {
      await ref.read(routineProvider.notifier).createRoutine(_nameController.text.trim(), _selectedExercises);
    } else {
      await ref.read(routineProvider.notifier).updateRoutine(widget.routine!.id!, _nameController.text.trim(), _selectedExercises);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }
}
