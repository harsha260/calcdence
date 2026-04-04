import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/todo_item.dart';
import '../services/notification_service.dart';

class TodoProvider extends ChangeNotifier {
  List<TodoItem> _todos = [];
  bool _isLoaded = false;

  List<TodoItem> get todos => _todos;
  bool get isLoaded => _isLoaded;

  Future<void> loadTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('todos');
    if (jsonStr != null) {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      _todos = decoded.map((e) => TodoItem.fromJson(e)).toList();
    }
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(_todos.map((e) => e.toJson()).toList());
    await prefs.setString('todos', jsonStr);
  }

  Future<void> updateTodo(
    String id, {
    required String title,
    int? subjectId,
    String? subjectName,
    DateTime? startTime,
    DateTime? endTime,
    DateTime? notificationTime,
  }) async {
    final index = _todos.indexWhere((e) => e.id == id);
    if (index == -1) return;

    final existingTodo = _todos[index];
    int? newNotificationId = existingTodo.notificationId;

    // Handle reminder updates
    if (existingTodo.notificationId != null) {
      await NotificationService()
          .cancelNotification(existingTodo.notificationId!);
      newNotificationId = null;
    }

    if (notificationTime != null && notificationTime.isAfter(DateTime.now())) {
      newNotificationId =
          DateTime.now().millisecondsSinceEpoch.remainder(100000);
      try {
        await NotificationService().scheduleTodoReminder(
          id: newNotificationId,
          title: 'Task Reminder: $title',
          body: subjectName != null ? 'For $subjectName' : 'Upcoming task!',
          scheduledDate: notificationTime,
        );
      } catch (e) {
        debugPrint('TodoProvider: Error scheduling reminder: $e');
        newNotificationId = null;
      }
    }

    final updatedTodo = TodoItem(
      id: id,
      title: title,
      isDone: existingTodo.isDone,
      subjectId: subjectId,
      subjectName: subjectName,
      startTime: startTime,
      endTime: endTime,
      notificationTime: notificationTime,
      notificationId: newNotificationId,
    );

    _todos[index] = updatedTodo;
    _sortTodos();
    await _save();
    notifyListeners();
  }

  Future<void> addTodo({
    required String title,
    int? subjectId,
    String? subjectName,
    DateTime? startTime,
    DateTime? endTime,
    DateTime? notificationTime,
  }) async {
    int? notificationId;

    if (notificationTime != null && notificationTime.isAfter(DateTime.now())) {
      notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      try {
        await NotificationService().scheduleTodoReminder(
          id: notificationId,
          title: 'Task Reminder: $title',
          body: subjectName != null ? 'For $subjectName' : 'Upcoming task!',
          scheduledDate: notificationTime,
        );
      } catch (e) {
        debugPrint('TodoProvider: Error scheduling reminder: $e');
        notificationId = null;
      }
    }

    final newTodo = TodoItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      subjectId: subjectId,
      subjectName: subjectName,
      startTime: startTime,
      endTime: endTime,
      notificationTime: notificationTime,
      notificationId: notificationId,
    );

    _todos.add(newTodo);
    _sortTodos();
    await _save();
    notifyListeners();
  }

  Future<void> toggleTodo(String id) async {
    final index = _todos.indexWhere((e) => e.id == id);
    if (index != -1) {
      final item = _todos[index];
      final newIsDone = !item.isDone;

      // Cancel reminder if completed
      if (newIsDone && item.notificationId != null) {
        await NotificationService().cancelNotification(item.notificationId!);
      }

      _todos[index] = item.copyWith(isDone: newIsDone);
      _sortTodos();
      await _save();
      notifyListeners();
    }
  }

  Future<void> deleteTodo(String id) async {
    final index = _todos.indexWhere((e) => e.id == id);
    if (index != -1) {
      final item = _todos[index];
      if (item.notificationId != null) {
        await NotificationService().cancelNotification(item.notificationId!);
      }
      _todos.removeAt(index);
      await _save();
      notifyListeners();
    }
  }

  void _sortTodos() {
    _todos.sort((a, b) {
      // Completed items go to the bottom
      if (a.isDone && !b.isDone) return 1;
      if (!a.isDone && b.isDone) return -1;

      // Sort by end time (nulls last)
      if (a.endTime != null && b.endTime != null) {
        return a.endTime!.compareTo(b.endTime!);
      }
      if (a.endTime != null) return -1;
      if (b.endTime != null) return 1;

      return 0; // Maintain order
    });
  }
}
