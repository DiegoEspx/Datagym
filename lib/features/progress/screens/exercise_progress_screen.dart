import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../session/providers/session_provider.dart';
import '../../session/models/exercise_catalog.dart';
import '../../session/screens/catalog_screen.dart';

class ExerciseProgressScreen extends ConsumerStatefulWidget {
  const ExerciseProgressScreen({super.key});

  @override
  ConsumerState<ExerciseProgressScreen> createState() => _ExerciseProgressScreenState();
}

class _ExerciseProgressScreenState extends ConsumerState<ExerciseProgressScreen> {
  final TextEditingController _searchController = TextEditingController();
  ExerciseCatalog? _selectedExercise;
  List<ExerciseCatalog> _allExercises = [];
  List<ExerciseCatalog> _suggestions = [];
  List<Map<String, dynamic>> _prData = [];
  List<Map<String, dynamic>> _historyData = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAllExercises();
  }

  Future<void> _loadAllExercises() async {
    final results = await ref.read(sessionProvider.notifier).searchCatalog('');
    if (!mounted) return;
    setState(() {
      _allExercises = results;
      _suggestions = results;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _trendLabel() {
    if (_prData.length < 2) return 'Tendencia: sin datos suficientes';
    final first = (_prData.first['daily_max'] as num).toDouble();
    final last = (_prData.last['daily_max'] as num).toDouble();
    if (last > first) return 'Tendencia: progresando';
    if (last < first) return 'Tendencia: bajó ligeramente';
    return 'Tendencia: estable';
  }

  void _onSearchChanged(String query) async {
    if (query.isEmpty) {
      setState(() => _suggestions = _allExercises);
      return;
    }
    final results = await ref.read(sessionProvider.notifier).searchCatalog(query);
    setState(() => _suggestions = results);
  }

  void _selectExercise(ExerciseCatalog exercise) async {
    setState(() {
      _selectedExercise = exercise;
      _suggestions = [];
      _searchController.text = exercise.name;
      _isLoading = true;
    });

    final prs = await ref.read(sessionProvider.notifier).getPREvolution(exercise.id!);
    final history = await ref.read(sessionProvider.notifier).getExerciseHistory(exercise.id!);

    setState(() {
      _prData = prs;
      _historyData = history;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final listToShow = _searchController.text.isEmpty ? _allExercises : _suggestions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progreso de Ejercicio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CatalogScreen()));
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Buscar ejercicio...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
            ),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: listToShow.length,
                itemBuilder: (context, index) {
                  final ex = listToShow[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      title: Text(ex.name),
                      onTap: () => _selectExercise(ex),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_selectedExercise != null)
              Expanded(
                child: ListView(
                  children: [
                    const Text('Evolución de PR (Peso Máximo)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(_trendLabel(), style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 16),
                    _buildChart(),
                    const SizedBox(height: 32),
                    const Text('Historial', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _buildHistoryTable(),
                  ],
                ),
              )
            else
              const Expanded(child: Center(child: Text('Busca un ejercicio para ver tu progreso'))),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    if (_prData.isEmpty) return const SizedBox(height: 200, child: Center(child: Text('Sin datos suficientes para graficar')));

    final spots = _prData.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), (entry.value['daily_max'] as num).toDouble());
    }).toList();

    return SizedBox(
      height: 250,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: true, border: Border.all(color: Colors.white24)),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.blueAccent,
              barWidth: 4,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: Colors.blueAccent.withValues(alpha: 0.1)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTable() {
    if (_historyData.isEmpty) return const Center(child: Text('No hay historial registrado.'));

    return Column(
      children: _historyData.map((session) {
        final sets = (session['sets'] as List).cast<Map<String, dynamic>>();
        final setsString = sets.map((s) => '${s['weight']}${s['unit']} x ${s['reps']}').join(' / ');

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(session['date']),
            subtitle: Text(setsString),
            trailing: session['notes'] != null ? const Icon(Icons.note_alt, size: 16) : null,
          ),
        );
      }).toList(),
    );
  }
}
