import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import '../providers/timetable_provider.dart';
import '../models/timetable_entry.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.week;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Academic Calendar'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Consumer<TimetableProvider>(
        builder: (context, timetable, _) {
          return Column(
            children: [
              TableCalendar(
                firstDay: DateTime.utc(2025, 1, 1),
                lastDay: DateTime.utc(2026, 12, 31),
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
                  setState(() {
                    _calendarFormat = format;
                  });
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
                eventLoader: (day) {
                  return timetable.periodsForDate(day);
                },
                calendarStyle: const CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: Colors.deepPurpleAccent,
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: Colors.deepPurple,
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: BoxDecoration(
                    color: Colors.blueAccent,
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                  ),
                ),
              ),
              const Divider(),
              Expanded(
                child: _buildEventList(timetable.periodsForDate(_selectedDay ?? _focusedDay)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEventList(List<TimetableEntry> events) {
    if (events.isEmpty) {
      return const Center(
        child: Text('No classes scheduled for this day.'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final entry = events[index];
        final now = DateTime.now();
        final sessionDate = entry.sessionDate != null ? DateTime.parse(entry.sessionDate!) : now;
        final startDt = entry.startDateTime(sessionDate);
        final isPast = startDt.isBefore(now);
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'P${entry.period}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            title: Text(
              entry.subjectName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${entry.startTime} - ${entry.endTime}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (entry.isAttended != null)
                  Icon(
                    entry.isAttended! ? Icons.check_circle : Icons.cancel,
                    color: entry.isAttended! ? Colors.green : Colors.red,
                  )
                else if (isPast)
                  Icon(Icons.help_outline, color: Theme.of(context).disabledColor),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => _showSessionDetails(entry),
          ),
        );
      },
    );
  }

  void _showSessionDetails(TimetableEntry entry) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.subjectName,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Period ${entry.period} • ${entry.startTime} - ${entry.endTime}',
                style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6)),
              ),
              const Divider(height: 32),
              const Text(
                'Session Topic',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                entry.topic ?? 'No topic recorded for this session.',
                style: TextStyle(
                  fontSize: 15,
                  fontStyle: entry.topic == null ? FontStyle.italic : FontStyle.normal,
                  color: entry.topic == null ? Theme.of(context).disabledColor : null,
                ),
              ),
              const SizedBox(height: 24),
              if (entry.isAttended != null)
                Row(
                  children: [
                    Icon(
                      entry.isAttended! ? Icons.check_circle : Icons.cancel,
                      color: entry.isAttended! ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      entry.isAttended! ? 'You attended this class' : 'You missed this class',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: entry.isAttended! ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
