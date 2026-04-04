import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/todo_item.dart';
import '../providers/todo_provider.dart';
import '../widgets/todo_bottom_sheet.dart';

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TodoProvider>().loadTodos();
    });
  }

  String _shortenSubjectName(String name) {
    if (name.length <= 15) return name;
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length > 1) {
      final initials = words
          .where((w) => w.isNotEmpty)
          .map((w) => w[0].toUpperCase())
          .join('');
      if (initials.length > 1) return initials;
    }
    return '${name.substring(0, 12)}...';
  }

  void _showTodoDetailsDialog(BuildContext context, TodoItem todo) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(todo.title,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (todo.subjectName != null) ...[
                Text('Subject', style: Theme.of(context).textTheme.bodySmall),
                Text(todo.subjectName!,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
              ],
              if (todo.startTime != null || todo.endTime != null) ...[
                Text('Time', style: Theme.of(context).textTheme.bodySmall),
                Text(_formatTimeRange(todo.startTime, todo.endTime),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
              ],
              if (todo.notificationId != null) ...[
                Row(
                  children: [
                    const Icon(Icons.notifications_active,
                        size: 16, color: Colors.deepPurple),
                    const SizedBox(width: 8),
                    Text(
                      todo.notificationTime != null
                          ? 'Reminder at ${DateFormat('hh:mm a').format(todo.notificationTime!)}'
                          : 'Reminder set',
                      style: const TextStyle(
                          color: Colors.deepPurple,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showEditDialog(todo);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Edit'),
            ),
          ],
        );
      },
    );
  }

  void _showEditDialog(TodoItem todo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).canvasColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => TodoBottomSheet(existingTodo: todo),
    );
  }

  void _showAddDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).canvasColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const TodoBottomSheet(),
    );
  }

  String _formatTimeRange(DateTime? start, DateTime? end) {
    if (start == null && end == null) return '';
    final DateFormat fmt = DateFormat('MMM dd, hh:mm a');

    if (start != null && end != null) {
      // If same day, don't repeat the date part
      if (start.year == end.year &&
          start.month == end.month &&
          start.day == end.day) {
        final DateFormat timeFmt = DateFormat('hh:mm a');
        return '${fmt.format(start)} - ${timeFmt.format(end)}';
      }
      return '${fmt.format(start)} - ${fmt.format(end)}';
    } else if (start != null) {
      return 'Starts ${fmt.format(start)}';
    } else {
      return 'Ends ${fmt.format(end!)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('To-Do List'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Consumer<TodoProvider>(
        builder: (context, provider, _) {
          if (!provider.isLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.todos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.playlist_add_check,
                    size: 64,
                    color: Theme.of(context).disabledColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Stay organized! Add your first task.',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.todos.length,
            itemBuilder: (context, index) {
              final todo = provider.todos[index];
              final isOverdue = todo.endTime != null &&
                  !todo.isDone &&
                  todo.endTime!.isBefore(DateTime.now());

              return Card(
                elevation: todo.isDone ? 0 : 2,
                color: todo.isDone
                    ? Theme.of(context).cardColor.withValues(alpha: 0.7)
                    : isOverdue
                        ? Colors.red.withValues(alpha: 0.05)
                        : null,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isOverdue
                      ? BorderSide(color: Colors.red.withValues(alpha: 0.3))
                      : BorderSide.none,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ListTile(
                    onTap: () => _showTodoDetailsDialog(context, todo),
                    leading: Checkbox(
                      value: todo.isDone,
                      onChanged: (val) => provider.toggleTodo(todo.id),
                      activeColor: Colors.deepPurple,
                    ),
                    title: Text(
                      todo.title,
                      style: TextStyle(
                        fontSize: 16,
                        decoration:
                            todo.isDone ? TextDecoration.lineThrough : null,
                        color: todo.isDone
                            ? Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.color
                                ?.withValues(alpha: 0.6)
                            : isOverdue
                                ? Colors.red.shade700
                                : null,
                        fontWeight:
                            todo.isDone ? FontWeight.normal : FontWeight.w600,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (todo.subjectName != null)
                          Container(
                            margin: const EdgeInsets.only(top: 6, bottom: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _shortenSubjectName(todo.subjectName!),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.deepPurple,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        if (todo.startTime != null || todo.endTime != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: isOverdue ? Colors.red : Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    _formatTimeRange(
                                        todo.startTime, todo.endTime),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          isOverdue ? Colors.red : Colors.grey,
                                      fontWeight: isOverdue
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (todo.notificationId != null && !todo.isDone)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 4.0),
                                    child: Icon(
                                      Icons.notifications_active,
                                      size: 12,
                                      color: Colors.deepPurple,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                      onPressed: () => provider.deleteTodo(todo.id),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
