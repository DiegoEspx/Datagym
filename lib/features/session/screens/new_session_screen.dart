import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/session_provider.dart';
import '../../routines/providers/routine_provider.dart';
import '../../routines/models/routine.dart';
import '../models/exercise_catalog.dart';
import '../../../shared/widgets/set_row_widget.dart';

class NewSessionScreen extends ConsumerStatefulWidget {
  final Routine? routine;
  const NewSessionScreen({super.key, this.routine});

  @override
  ConsumerState<NewSessionScreen> createState() => _NewSessionScreenState();
}

class _NewSessionScreenState extends ConsumerState<NewSessionScreen> {
  final List<Map<String, dynamic>> _sessionExercises = [];
  final _dateController = TextEditingController(text: DateTime.now().toString().split(' ')[0]);
  final _sessionNotesController = TextEditingController();
  bool _isLoading = false;

  List<List<int>> _buildRenderGroups() {
    final groups = <List<int>>[];
    final visited = <int>{};

    for (int i = 0; i < _sessionExercises.length; i++) {
      if (visited.contains(i)) continue;

      final supersetId = _sessionExercises[i]['superset_id'];
      if (supersetId == null) {
        groups.add([i]);
        visited.add(i);
        continue;
      }

      final group = <int>[];
      for (int j = i; j < _sessionExercises.length; j++) {
        if (!visited.contains(j) && _sessionExercises[j]['superset_id'] == supersetId) {
          group.add(j);
          visited.add(j);
        }
      }

      if (group.isEmpty) {
        groups.add([i]);
        visited.add(i);
      } else {
        groups.add(group);
      }
    }

    return groups;
  }

  Widget _buildSupersetDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: const [
          Expanded(child: Divider()),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text('Biserie', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          Expanded(child: Divider()),
        ],
      ),
    );
  }

  Widget _buildExerciseSection(int exIndex) {
    final ex = _sessionExercises[exIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                ex['name'] as String,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.link, size: 20),
              onPressed: () => _showSupersetSelector(exIndex),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
              onPressed: () => setState(() {
                final supersetId = _sessionExercises[exIndex]['superset_id'];
                _sessionExercises.removeAt(exIndex);
                if (supersetId != null) {
                  for (final exercise in _sessionExercises) {
                    if (exercise['superset_id'] == supersetId) {
                      exercise['superset_id'] = null;
                    }
                  }
                }
              }),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...((_sessionExercises[exIndex]['sets'] as List).asMap().entries.map((setEntry) {
          final setIndex = setEntry.key;
          final setData = setEntry.value;
          return SetRowWidget(
            key: ValueKey('${_sessionExercises[exIndex]['catalog_id']}_$setIndex'),
            index: setData['set_number'] as int,
            weight: setData['weight'],
            reps: setData['reps'],
            isDropSet: ((setData['drop_index'] as num?) ?? 0) > 0,
            onAddDrop: ((setData['drop_index'] as num?) ?? 0) == 0
                ? () => setState(() {
                    final sets = List<Map<String, dynamic>>.from(
                      _sessionExercises[exIndex]['sets'] as List,
                    );
                    final currentSet = sets[setIndex];
                    sets.insert(setIndex + 1, {
                      'set_number': currentSet['set_number'],
                      'weight': currentSet['weight'],
                      'reps': 0,
                      'drop_index': ((currentSet['drop_index'] as num?) ?? 0).toInt() + 1,
                    });
                    _sessionExercises[exIndex]['sets'] = sets;
                  })
                : null,
            onRemove: () => setState(() {
              final sets = List<Map<String, dynamic>>.from(
                _sessionExercises[exIndex]['sets'] as List,
              );
              sets.removeAt(setIndex);
              if (sets.isEmpty) {
                _sessionExercises.removeAt(exIndex);
              } else {
                _sessionExercises[exIndex]['sets'] = sets;
              }
            }),
            onWeightChanged: (val) => (_sessionExercises[exIndex]['sets'] as List)[setIndex]['weight'] = val,
            onRepsChanged: (val) => (_sessionExercises[exIndex]['sets'] as List)[setIndex]['reps'] = val,
          );
        })),
        TextButton.icon(
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Añadir set'),
          onPressed: () => setState(() {
            final sets = List<Map<String, dynamic>>.from(
              _sessionExercises[exIndex]['sets'] as List,
            );
            final lastSet = sets.last;
            sets.add({
              'set_number': sets.where((s) => ((s['drop_index'] as num?) ?? 0) == 0).length + 1,
              'weight': lastSet['weight'],
              'reps': lastSet['reps'],
              'drop_index': 0,
            });
            _sessionExercises[exIndex]['sets'] = sets;
          }),
        ),
      ],
    );
  }

  Future<void> _showSupersetSelector(int exIndex) async {
    await showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        final currentSupersetId = _sessionExercises[exIndex]['superset_id'];
        final candidates = <MapEntry<int, Map<String, dynamic>>>[];
        for (int i = 0; i < _sessionExercises.length; i++) {
          if (i != exIndex) {
            candidates.add(MapEntry(i, _sessionExercises[i]));
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
                if (currentSupersetId != null)
                  ListTile(
                    leading: const Icon(Icons.link_off),
                    title: const Text('Desvincular'),
                    onTap: () {
                      setState(() {
                        for (final exercise in _sessionExercises) {
                          if (exercise['superset_id'] == currentSupersetId) {
                            exercise['superset_id'] = null;
                          }
                        }
                      });
                      Navigator.pop(sheetContext);
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
                  ...candidates.map(
                    (entry) => ListTile(
                      leading: const Icon(Icons.fitness_center),
                      title: Text(entry.value['name'] as String),
                      onTap: () {
                        final linkedIndex = entry.key;
                        final linkedSupersetId = _sessionExercises[linkedIndex]['superset_id'];
                        final newSupersetId = exIndex;
                        setState(() {
                          for (final exercise in _sessionExercises) {
                            if (exercise['superset_id'] == currentSupersetId ||
                                exercise['superset_id'] == linkedSupersetId) {
                              exercise['superset_id'] = null;
                            }
                          }
                          _sessionExercises[exIndex]['superset_id'] = newSupersetId;
                          _sessionExercises[linkedIndex]['superset_id'] = newSupersetId;
                        });
                        Navigator.pop(sheetContext);
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _dateController.dispose();
    _sessionNotesController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.routine != null) {
      _loadRoutineExercises();
    }
  }

  Future<void> _loadRoutineExercises() async {
    final exercises = await ref.read(routineProvider.notifier).getRoutineExercises(widget.routine!.id!);
    if (!mounted) return;
    setState(() {
      for (var ex in exercises) {
        _sessionExercises.add({
          'catalog_id': ex['id'],
          'name': ex['name'],
          'superset_id': ex['superset_group'],
          'notes': '',
          'sets': [
            {'set_number': 1, 'weight': 0.0, 'reps': 0, 'drop_index': 0}
          ],
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final renderGroups = _buildRenderGroups();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.routine?.name ?? 'Sesión Libre'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            TextButton(
              onPressed: _finishSession,
              child: const Text('Finalizar', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _dateController,
                            decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                            readOnly: true,
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (date != null) {
                                _dateController.text = date.toString().split(' ')[0];
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _sessionNotesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'Notas opcionales de la sesión...',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _sessionExercises.isEmpty
                ? const Center(child: Text('Agrega ejercicios para empezar'))
                : ListView.builder(
                    itemCount: renderGroups.length,
                    itemBuilder: (context, groupIndex) {
                      final group = renderGroups[groupIndex];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (int i = 0; i < group.length; i++) ...[
                                _buildExerciseSection(group[i]),
                                if (i < group.length - 1) _buildSupersetDivider(),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Añadir Ejercicio'),
            onPressed: _isLoading ? null : _addExercise,
          ),
        ),
      ),
    );
  }

  void _addExercise() {
    final searchController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(16),
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
                            if (!ctx.mounted) return;
                            setState(() {
                              _sessionExercises.add({
                                'catalog_id': id,
                                'name': searchController.text,
                                'notes': '',
                                'sets': [{'set_number': 1, 'weight': 0.0, 'reps': 0, 'drop_index': 0}],
                              });
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
                                _sessionExercises.add({
                                  'catalog_id': items[i].id,
                                  'name': items[i].name,
                                  'notes': '',
                                  'sets': [{'set_number': 1, 'weight': 0.0, 'reps': 0, 'drop_index': 0}],
                                });
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
            );
          }
        );
      },
    );
  }

  Future<void> _finishSession() async {
    if (_sessionExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un ejercicio antes de finalizar.')),
      );
      return;
    }

    for (final exercise in _sessionExercises) {
      final sets = exercise['sets'] as List<Map<String, dynamic>>;
      if (sets.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('El ejercicio ${exercise['name']} no tiene sets.')),
        );
        return;
      }
      final hasInvalidSet = sets.any((s) => (s['weight'] as num) <= 0 || (s['reps'] as num) <= 0);
      if (hasInvalidSet) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Corrige peso y reps en ${exercise['name']} (deben ser mayores a 0).')),
        );
        return;
      }
    }

    if (widget.routine != null) {
      final originalExercises = await ref.read(routineProvider.notifier).getRoutineExercises(widget.routine!.id!);
      bool differs = originalExercises.length != _sessionExercises.length;
      if (!differs) {
        for (int i = 0; i < originalExercises.length; i++) {
          if (originalExercises[i]['id'] != _sessionExercises[i]['catalog_id']) {
            differs = true;
            break;
          }
        }
      }

      if (differs) {
        _showSaveModal();
        return;
      }
    }

    _saveAndExit(null);
  }

  void _showSaveModal() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cambios en la rutina?'),
        content: const Text('Detectamos cambios respecto a la plantilla original.'),
        actions: [
          TextButton(
            child: const Text('Actualizar rutina existente'),
            onPressed: () {
              Navigator.pop(context);
              _saveAndExit(1);
            },
          ),
          TextButton(
            child: const Text('Guardar como nueva rutina'),
            onPressed: () {
              Navigator.pop(context);
              _saveAndExit(2);
            },
          ),
          TextButton(
            child: const Text('Nada, solo esta sesión'),
            onPressed: () {
              Navigator.pop(context);
              _saveAndExit(0);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _saveAndExit(int? routineOption) async {
    setState(() => _isLoading = true);

    try {
      await ref.read(sessionProvider.notifier).saveSession(
        date: _dateController.text,
        routineId: widget.routine?.id,
        notes: _sessionNotesController.text.trim().isEmpty ? null : _sessionNotesController.text.trim(),
        exercisesWithSets: _sessionExercises,
      );

      if (routineOption == 1 && widget.routine != null) {
        await ref.read(routineProvider.notifier).updateRoutine(
          widget.routine!.id!,
          widget.routine!.name,
          _sessionExercises.map((e) => ExerciseCatalog(id: e['catalog_id'], name: e['name'], nameNormalized: e['name'].toString().toLowerCase())).toList(),
        );
      } else if (routineOption == 2) {
        await ref.read(routineProvider.notifier).createRoutine(
          "${widget.routine?.name ?? 'Rutina'} (Copia)",
          _sessionExercises.map((e) => ExerciseCatalog(id: e['catalog_id'], name: e['name'], nameNormalized: e['name'].toString().toLowerCase())).toList(),
        );
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar la sesión. Intenta de nuevo.')),
      );
    }
  }
}