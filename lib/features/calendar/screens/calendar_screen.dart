import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../session/providers/session_provider.dart';
import '../../session/screens/session_detail_screen.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateUtils.dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(sessionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Calendario')),
      body: sessionsAsync.when(
        data: (sessions) {
          final Map<DateTime, List<dynamic>> sessionsByDate = {};
          for (var session in sessions) {
            final dateKey = DateUtils.dateOnly(DateTime.parse(session.date));
            sessionsByDate[dateKey] = [...(sessionsByDate[dateKey] ?? []), session];
          }

          return Column(
            children: [
              TableCalendar(
                locale: 'es_ES',
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.now().add(const Duration(days: 365)),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                onFormatChanged: (format) {
                  if (_calendarFormat != format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  }
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
                eventLoader: (day) {
                  final dateKey = DateUtils.dateOnly(day);
                  return sessionsByDate[dateKey] ?? [];
                },
                calendarStyle: CalendarStyle(
                  selectedDecoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
                  todayDecoration: BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                  markerDecoration: BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                ),
              ),
              const Divider(),
              Expanded(
                child: _selectedDay == null
                    ? const Center(child: Text('Selecciona un día para ver detalles'))
                    : _buildSessionListForDay(sessionsByDate[DateUtils.dateOnly(_selectedDay!)]),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildSessionListForDay(List? sessions) {
    if (sessions == null || sessions.isEmpty) {
      return const Center(child: Text('No hay sesiones registradas este día.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.fitness_center),
            title: Text('Sesión: ${session.date}'),
            subtitle: session.notes != null ? Text(session.notes!) : const Text('Ver detalles'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => SessionDetailScreen(session: session)));
            },
          ),
        );
      },
    );
  }
}
