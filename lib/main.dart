import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'features/routines/screens/routines_list_screen.dart';
import 'features/routines/providers/routine_provider.dart';
import 'features/session/providers/session_provider.dart';
import 'features/session/screens/new_session_screen.dart';
import 'features/session/screens/session_detail_screen.dart';
import 'features/calendar/screens/calendar_screen.dart';
import 'features/progress/screens/exercise_progress_screen.dart';
import 'features/chat/screens/chat_screen.dart';
import 'features/session/providers/draft_session_provider.dart';
import 'core/services/excel_export_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(
    const ProviderScope(
      child: DataGymApp(),
    ),
  );
}

class DataGymApp extends StatelessWidget {
  const DataGymApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DataGym',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'),
      ],
      locale: const Locale('es', 'ES'),
      home: const MainContainer(),
    );
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _formatDate(String isoDate) {
    final date = DateTime.tryParse(isoDate);
    if (date == null) return isoDate;

    const weekdays = [
      'lunes',
      'martes',
      'miercoles',
      'jueves',
      'viernes',
      'sabado',
      'domingo',
    ];

    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];

    final weekday = weekdays[date.weekday - 1];
    final month = months[date.month - 1];
    return '$weekday, ${date.day} de $month de ${date.year}';
  }

  Future<void> _showRoutineSelector(BuildContext context, WidgetRef ref) async {
    final routines = ref.read(routineProvider);

    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '¿Qué entrenas hoy?',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 12),
                if (routines.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('No tienes rutinas guardadas todavía.'),
                    ),
                  )
                else
                  ...routines.map(
                    (routine) => ListTile(
                      title: Text(routine.name),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NewSessionScreen(routine: routine),
                          ),
                        );
                        ref.read(sessionProvider.notifier).loadSessions();
                      },
                    ),
                  ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.fitness_center),
                  title: const Text('Sesión libre'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NewSessionScreen()),
                    );
                    ref.read(sessionProvider.notifier).loadSessions();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'DataGym',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Exportar a Excel',
            onPressed: () async {
              try {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Generando Excel...')),
                );
                await ExcelExportService.exportAndShare();
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: [colors.primary.withValues(alpha: 0.75), colors.secondary.withValues(alpha: 0.65)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Entrena con foco', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 8),
                  const Text('Registra tu sesión y revisa tu progreso en segundos.', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Nueva sesión de hoy'),
                    onPressed: () => _showRoutineSelector(context, ref),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Builder(
              builder: (context) {
                final draft = ref.watch(draftSessionProvider);
                if (draft == null) return const SizedBox.shrink();

                final draftRoutineId = draft['routineId'] as int?;
                final routines = ref.read(routineProvider);
                final matchedRoutine = draftRoutineId != null
                    ? routines.where((r) => r.id == draftRoutineId).firstOrNull
                    : null;
                final label = matchedRoutine != null
                    ? 'Continuar: ${matchedRoutine.name}'
                    : 'Continuar sesión libre';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Card(
                    color: Colors.amber.shade900.withValues(alpha: 0.35),
                    child: ListTile(
                      leading: const Icon(Icons.edit_note, color: Colors.amber),
                      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('Sesión de hoy · Toca para continuar'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NewSessionScreen(routine: matchedRoutine),
                          ),
                        );
                        ref.read(sessionProvider.notifier).loadSessions();
                      },
                    ),
                  ),
                );
              },
            ),
            const Text('Asistente IA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: Icon(Icons.psychology, color: colors.primary),
                title: const Text('Pregunta sobre tu progreso'),
                subtitle: const Text('¿Cómo voy con mi press de banca?'),
                trailing: const Icon(Icons.chat),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen()));
                },
              ),
            ),
            const SizedBox(height: 20),
            const Text('Últimas sesiones', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Expanded(
              child: sessionsAsync.when(
                data: (sessions) => sessions.isEmpty
                    ? const Center(child: Text('Aún no has registrado entrenamientos.'))
                    : ListView.builder(
                        itemCount: sessions.length,
                        itemBuilder: (context, index) {
                          final session = sessions[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: colors.primary.withValues(alpha: 0.18),
                                child: Icon(Icons.fitness_center, color: colors.primary),
                              ),
                              title: Text(_formatDate(session.date), style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: session.notes != null ? Text(session.notes!) : null,
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => SessionDetailScreen(session: session)));
                              },
                            ),
                          );
                        },
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MainContainer extends StatefulWidget {
  const MainContainer({super.key});

  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const RoutinesListScreen(),
    const CalendarScreen(),
    const ExerciseProgressScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        height: 74,
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.fitness_center), label: 'Rutinas'),
          NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Calendario'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Progreso'),
        ],
      ),
    );
  }
}
