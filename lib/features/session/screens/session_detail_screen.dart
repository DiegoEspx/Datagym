import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/session_provider.dart';
import '../models/session.dart';

class SessionDetailScreen extends ConsumerWidget {
  final Session session;
  const SessionDetailScreen({super.key, required this.session});

  String _formatDate(String isoDate) {
    final parts = isoDate.split('-');
    if (parts.length != 3) return isoDate;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  List<List<int>> _buildRenderGroups(List<Map<String, dynamic>> details) {
    final groups = <List<int>>[];
    final visited = <int>{};

    for (int i = 0; i < details.length; i++) {
      if (visited.contains(i)) continue;

      final supersetId = details[i]['superset_id'];
      if (supersetId == null) {
        groups.add([i]);
        visited.add(i);
        continue;
      }

      final group = <int>[];
      for (int j = i; j < details.length; j++) {
        if (!visited.contains(j) && details[j]['superset_id'] == supersetId) {
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

  Widget _buildExerciseSection(Map<String, dynamic> ex) {
    final sets = ex['sets'] as List;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(ex['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        if (ex['notes'] != null && ex['notes'].isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(ex['notes'], style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
          ),
        const Divider(),
        ...sets.map(
          (s) {
            final isDropSet = ((s['drop_index'] as num?) ?? 0) > 0;
            final label = isDropSet ? '  ↳ Drop ${s['drop_index']}' : 'Set ${s['set_number']}';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('${s['weight']} ${s['unit']} x ${s['reps']} reps'),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sesión: ${_formatDate(session.date)}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('¿Eliminar esta sesión?'),
                  content: const Text('Esta acción no se puede deshacer.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
                  ],
                ),
              );

              if (confirm != true) return;
              await ref.read(sessionProvider.notifier).deleteSession(session.id!);
              if (!context.mounted) return;
              Navigator.pop(context);
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref.read(sessionProvider.notifier).getSessionDetails(session.id!),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final details = snapshot.data!;
          final renderGroups = _buildRenderGroups(details);

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: renderGroups.length,
            itemBuilder: (context, index) {
              final group = renderGroups[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < group.length; i++) ...[
                        _buildExerciseSection(details[group[i]]),
                        if (i < group.length - 1) _buildSupersetDivider(),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
