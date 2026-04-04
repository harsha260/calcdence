import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/todo_provider.dart';
import '../providers/attendance_provider.dart';
import '../models/subject.dart';
import '../models/todo_item.dart';
import 'package:intl/intl.dart';

class TodoBottomSheet extends StatefulWidget {
  final TodoItem? existingTodo;

  const TodoBottomSheet({super.key, this.existingTodo});

  @override
  State<TodoBottomSheet> createState() => _TodoBottomSheetState();
}

class _TodoBottomSheetState extends State<TodoBottomSheet> {
  final TextEditingController _titleController = TextEditingController();
  Subject? _selectedSubject;
  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;

  bool _remindMe = false;
  int _reminderMinutesBefore = 0; // 0 = exactly at start time
  bool _isInit = true;

  @override
  void initState() {
    super.initState();
    if (widget.existingTodo != null) {
      final todo = widget.existingTodo!;
      _titleController.text = todo.title;
      _startDate = todo.startTime;
      if (todo.startTime != null) {
        _startTime = TimeOfDay.fromDateTime(todo.startTime!);
      }
      _endDate = todo.endTime;
      if (todo.endTime != null) {
        _endTime = TimeOfDay.fromDateTime(todo.endTime!);
      }
      if (todo.notificationId != null && todo.notificationTime != null) {
        _remindMe = true;
        final referenceTime = todo.startTime ?? todo.endTime;
        if (referenceTime != null) {
          _reminderMinutesBefore =
              referenceTime.difference(todo.notificationTime!).inMinutes;
        }
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit && widget.existingTodo != null) {
      final subjects =
          context.read<AttendanceProvider>().attendance?.subjects ?? [];
      _selectedSubject = subjects
          .where((s) => s.subjectCode == widget.existingTodo!.subjectId)
          .firstOrNull;
      _isInit = false;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _saveTask() {
    if (_titleController.text.trim().isEmpty) return;

    DateTime? finalStartTime;
    if (_startDate != null) {
      final sTime = _startTime ?? const TimeOfDay(hour: 9, minute: 0);
      finalStartTime = DateTime(
        _startDate!.year,
        _startDate!.month,
        _startDate!.day,
        sTime.hour,
        sTime.minute,
      );
    }

    DateTime? finalEndTime;
    if (_endDate != null) {
      final eTime = _endTime ?? const TimeOfDay(hour: 10, minute: 0);
      finalEndTime = DateTime(
        _endDate!.year,
        _endDate!.month,
        _endDate!.day,
        eTime.hour,
        eTime.minute,
      );
    }

    DateTime? notificationTime;
    if (_remindMe && finalStartTime != null) {
      notificationTime =
          finalStartTime.subtract(Duration(minutes: _reminderMinutesBefore));
    } else if (_remindMe && finalEndTime != null) {
      // Fallback to end time if start time is not set
      notificationTime =
          finalEndTime.subtract(Duration(minutes: _reminderMinutesBefore));
    }

    if (widget.existingTodo != null) {
      context.read<TodoProvider>().updateTodo(
            widget.existingTodo!.id,
            title: _titleController.text.trim(),
            subjectId: _selectedSubject?.subjectCode,
            subjectName: _selectedSubject?.subjectName,
            startTime: finalStartTime,
            endTime: finalEndTime,
            notificationTime: notificationTime,
          );
    } else {
      context.read<TodoProvider>().addTodo(
            title: _titleController.text.trim(),
            subjectId: _selectedSubject?.subjectCode,
            subjectName: _selectedSubject?.subjectName,
            startTime: finalStartTime,
            endTime: finalEndTime,
            notificationTime: notificationTime,
          );
    }

    Navigator.pop(context);
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final pickedRange = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: (_startDate != null && _endDate != null)
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.tealAccent,
              onPrimary: Colors.black,
              surface: Color(0xFF121212),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedRange != null) {
      setState(() {
        _startDate = pickedRange.start;
        _endDate = pickedRange.end;
      });
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final time = await showTimePicker(
      context: context,
      initialTime: isStart
          ? (_startTime ?? TimeOfDay.now())
          : (_endTime ?? TimeOfDay.now()),
    );
    if (time != null) {
      setState(() {
        if (isStart) {
          _startTime = time;
        } else {
          _endTime = time;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjects =
        context.read<AttendanceProvider>().attendance?.subjects ?? [];
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'New Task',
              style: textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              autofocus: true,
              style: textTheme.titleMedium,
              decoration: InputDecoration(
                hintText: 'What needs to be done?',
                hintStyle: textTheme.titleMedium?.copyWith(color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
            ),
            const SizedBox(height: 16),

            // Subject Dropdown
            if (subjects.isNotEmpty)
              DropdownButtonFormField<Subject>(
                value: _selectedSubject,
                hint: Text('Link to Subject (Optional)',
                    style: textTheme.bodyLarge),
                isExpanded: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                items: subjects.map((Subject s) {
                  return DropdownMenuItem<Subject>(
                    value: s,
                    child: Text(s.subjectName,
                        style: textTheme.bodyLarge,
                        overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedSubject = val),
              ),

            const SizedBox(height: 16),

            // Start Date & Time
            Text('Start Time (Optional)',
                style: textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDateRange,
                    icon: const Icon(Icons.calendar_today, size: 20),
                    label: Text(
                      _startDate != null
                          ? DateFormat('MMM dd').format(_startDate!)
                          : 'Add Start Date',
                      style: textTheme.bodyLarge,
                    ),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _startDate != null ? () => _pickTime(true) : null,
                    icon: const Icon(Icons.access_time, size: 20),
                    label: Text(
                      _startTime != null
                          ? _startTime!.format(context)
                          : 'Add Time',
                      style: textTheme.bodyLarge,
                    ),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // End Date & Time
            Text('End Time (Optional)',
                style: textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDateRange,
                    icon: const Icon(Icons.calendar_today, size: 20),
                    label: Text(
                      _endDate != null
                          ? DateFormat('MMM dd').format(_endDate!)
                          : 'Add End Date',
                      style: textTheme.bodyLarge,
                    ),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _endDate != null ? () => _pickTime(false) : null,
                    icon: const Icon(Icons.access_time, size: 20),
                    label: Text(
                      _endTime != null ? _endTime!.format(context) : 'Add Time',
                      style: textTheme.bodyLarge,
                    ),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
              ],
            ),

            // Remind Me Checkbox
            if (_startDate != null || _endDate != null) ...[
              const SizedBox(height: 16),
              SwitchListTile(
                title: Text('Remind Me', style: textTheme.titleMedium),
                subtitle: Text('Get a notification for this task',
                    style: textTheme.bodyMedium),
                value: _remindMe,
                onChanged: (val) => setState(() => _remindMe = val),
                contentPadding: EdgeInsets.zero,
                activeTrackColor: Colors.deepPurple,
              ),
              if (_remindMe)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: DropdownButtonFormField<int>(
                    value: _reminderMinutesBefore,
                    decoration: InputDecoration(
                      labelText: 'When to notify?',
                      labelStyle: textTheme.bodyLarge,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 0, child: Text('At time of event')),
                      DropdownMenuItem(
                          value: 5, child: Text('5 minutes before')),
                      DropdownMenuItem(
                          value: 15, child: Text('15 minutes before')),
                      DropdownMenuItem(
                          value: 30, child: Text('30 minutes before')),
                      DropdownMenuItem(value: 60, child: Text('1 hour before')),
                      DropdownMenuItem(
                          value: 1440, child: Text('1 day before')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _reminderMinutesBefore = val);
                      }
                    },
                  ),
                ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Save Task',
                    style: textTheme.titleMedium?.copyWith(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
