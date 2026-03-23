import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/session_provider.dart';
import '../providers/draft_session_provider.dart';
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

class _NewSessionScreenState extends ConsumerState<NewSessionScreen> with WidgetsBindingObserver {
  List<Map<String, dynamic>> _sessionExercises = [];
  final _dateController = TextEditingController(text: DateTime.now().toString().split(' ')[0]);
  final _sessionNotesController = TextEditingController();
  bool _isSaving = false;
  int? _savedSessionId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkDraft();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Auto-save when app goes to background or is about to be closed
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (mounted) _saveDraft();
    }
  }

  void _checkDraft() {
    final draft = ref.read(draftSessionProvider);
    if (draft != null) {
      final draftRoutineId = draft['routineId'];
      final currentRoutineId = widget.routine?.id;

      if (draftRoutineId == currentRoutineId) {
        _restoreDraft(draft);
        return;
      }
    }
    
    if (widget.routine != null) {
      _loadRoutineExercises();
    }
  }

  void _restoreDraft(Map<String, dynamic> draft) {
    setState(() {
      _dateController.text = draft['date'] ?? _dateController.text;
      _sessionNotesController.text = draft['notes'] ?? '';
      _savedSessionId = draft['sessionId'] as int?;
      _sessionExercises = List<Map<String, dynamic>>.from(
        (draft['exercises'] as List).map((e) => Map<String, dynamic>.from(e)),
      );
    });
  }

  void _saveDraft() {
    ref.read(draftSessionProvider.notifier).saveDraft(
          routineId: widget.routine?.id,
          date: _dateController.text,
          notes: _sessionNotesController.text,
          exercises: _sessionExercises,
          sessionId: _savedSessionId,
        );
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    if (!_isSaving) _saveDraft();
  }

  @override
  void deactivate() {
    // Save draft while ref is still valid (before dispose)
    _saveDraft();
    super.deactivate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dateController.dispose();
    _sessionNotesController.dispose();
    super.dispose();
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

  /// Save session to the database (create or update). Does NOT close the screen.
  Future<void> _saveSession() async {
    if (_sessionExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un ejercicio antes de guardar.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final notes = _sessionNotesController.text.trim().isEmpty
          ? null
          : _sessionNotesController.text.trim();

      if (_savedSessionId != null) {
        // Update existing session
        await ref.read(sessionProvider.notifier).updateSession(
          sessionId: _savedSessionId!,
          date: _dateController.text,
          routineId: widget.routine?.id,
          notes: notes,
          exercisesWithSets: _sessionExercises,
        );
      } else {
        // Create new session
        final newId = await ref.read(sessionProvider.notifier).saveSession(
          date: _dateController.text,
          routineId: widget.routine?.id,
          notes: notes,
          exercisesWithSets: _sessionExercises,
        );
        _savedSessionId = newId;
      }

      // Update draft with the sessionId
      _saveDraft();

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Sesión guardada ✓'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar. Intenta de nuevo.')),
      );
    }
  }

  /// Finish and close the session — clears the draft and goes back.
  Future<void> _finishAndClose() async {
    if (_sessionExercises.isEmpty) {
      // Nothing to save, just clear draft and go back
      ref.read(draftSessionProvider.notifier).clearDraft();
      Navigator.pop(context);
      return;
    }

    // Save first if there's unsaved data
    if (_savedSessionId == null) {
      await _saveSession();
    } else {
      // Update existing
      final notes = _sessionNotesController.text.trim().isEmpty
          ? null
          : _sessionNotesController.text.trim();
      await ref.read(sessionProvider.notifier).updateSession(
        sessionId: _savedSessionId!,
        date: _dateController.text,
        routineId: widget.routine?.id,
        notes: notes,
        exercisesWithSets: _sessionExercises,
      );
    }

    // Check if routine exercises changed
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

      if (differs && mounted) {
        await _showRoutineUpdateDialog();
      }
    }

    // Clear draft and close
    ref.read(draftSessionProvider.notifier).clearDraft();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _showRoutineUpdateDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cambios en la rutina?'),
        content: const Text('Detectamos cambios respecto a la plantilla original.'),
        actions: [
          TextButton(
            child: const Text('Actualizar rutina existente'),
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(routineProvider.notifier).updateRoutine(
                widget.routine!.id!,
                widget.routine!.name,
                _sessionExercises.map((e) => ExerciseCatalog(id: e['catalog_id'], name: e['name'], nameNormalized: e['name'].toString().toLowerCase())).toList(),
              );
            },
          ),
          TextButton(
            child: const Text('Guardar como nueva rutina'),
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(routineProvider.notifier).createRoutine(
                "${widget.routine?.name ?? 'Rutina'} (Copia)",
                _sessionExercises.map((e) => ExerciseCatalog(id: e['catalog_id'], name: e['name'], nameNormalized: e['name'].toString().toLowerCase())).toList(),
              );
            },
          ),
          TextButton(
            child: const Text('Nada, solo esta sesión'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

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
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.link, size: 14, color: Colors.amber),
          SizedBox(width: 8),
          Text(
            'Biserie / Superset',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.amber, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseSection(int exIndex) {
    final ex = _sessionExercises[exIndex];
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.fitness_center, size: 20, color: colors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ex['name'] as String,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  if (ex['notes'] != null && (ex['notes'] as String).isNotEmpty)
                    Text(
                      ex['notes'] as String,
                      style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (val) {
                if (val == 'rename') {
                  _showRenameDialog(exIndex);
                } else if (val == 'superset') {
                  _showSupersetSelector(exIndex);
                } else if (val == 'delete') {
                  setState(() {
                    final supersetId = _sessionExercises[exIndex]['superset_id'];
                    _sessionExercises.removeAt(exIndex);
                    if (supersetId != null) {
                      for (final exercise in _sessionExercises) {
                        if (exercise['superset_id'] == supersetId) {
                          exercise['superset_id'] = null;
                        }
                      }
                    }
                  });
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'rename',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 8),
                      Text('Editar nombre'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'superset',
                  child: Row(
                    children: [
                      Icon(Icons.link, size: 18),
                      SizedBox(width: 8),
                      Text('Vincular biserie'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18, color: colors.error),
                      const SizedBox(width: 8),
                      Text('Eliminar', style: TextStyle(color: colors.error)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...((_sessionExercises[exIndex]['sets'] as List).asMap().entries.map((setEntry) {
          final setIndex = setEntry.key;
          final setData = setEntry.value;
          return SetRowWidget(
            key: ValueKey('${_sessionExercises[exIndex]['catalog_id']}_${setData['set_number']}_${setData['drop_index']}'),
            index: setData['set_number'] as int,
            weight: (setData['weight'] as num).toDouble(),
            reps: setData['reps'] as int,
            isDropSet: ((setData['drop_index'] as num?) ?? 0) > 0,
            onFieldEditComplete: _saveDraft,
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
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: colors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: const Text('Añadir set', style: TextStyle(fontWeight: FontWeight.w700)),
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
        ),
      ],
    );
  }

  Future<void> _showRenameDialog(int exIndex) async {
    final currentName = _sessionExercises[exIndex]['name'] as String;
    final controller = TextEditingController(text: currentName);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar nombre'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nombre del ejercicio'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || newName == currentName) return;

    final catalogId = _sessionExercises[exIndex]['catalog_id'] as int;

    // Update in DB globally
    await ref.read(sessionProvider.notifier).renameCatalogItem(catalogId, newName);

    // Update all occurrences in the current session
    setState(() {
      for (final ex in _sessionExercises) {
        if (ex['catalog_id'] == catalogId) {
          ex['name'] = newName;
        }
      }
    });
  }

  Future<void> _showSupersetSelector(int exIndex) async {
    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
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
  Widget build(BuildContext context) {
    final renderGroups = _buildRenderGroups();
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.routine?.name ?? 'Sesión Libre'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Guardar',
              onPressed: _saveSession,
            ),
            IconButton(
              icon: const Icon(Icons.check_circle_outline),
              tooltip: 'Finalizar y salir',
              onPressed: _finishAndClose,
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Status indicator
          if (_savedSessionId != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: colors.primary.withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(Icons.cloud_done, size: 16, color: colors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Sesión guardada · Puedes seguir editando',
                    style: TextStyle(fontSize: 12, color: colors.primary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
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
                      onChanged: (_) => _saveDraft(),
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Añadir Ejercicio'),
            onPressed: _isSaving ? null : _addExercise,
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
            ));
          }
        );
      },
    );
  }
}
