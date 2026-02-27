import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TodoItem {
  final String id;
  final String title;
  final bool isDone;

  TodoItem({
    required this.id,
    required this.title,
    this.isDone = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'isDone': isDone,
  };

  factory TodoItem.fromJson(Map<String, dynamic> json) => TodoItem(
    id: json['id'],
    title: json['title'],
    isDone: json['isDone'] ?? false,
  );

  TodoItem copyWith({String? title, bool? isDone}) {
    return TodoItem(
      id: id,
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
    );
  }
}

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

  Future<void> addTodo(String title) async {
    final newTodo = TodoItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
    );
    _todos.add(newTodo);
    await _save();
    notifyListeners();
  }

  Future<void> toggleTodo(String id) async {
    final index = _todos.indexWhere((e) => e.id == id);
    if (index != -1) {
      _todos[index] = _todos[index].copyWith(isDone: !_todos[index].isDone);
      await _save();
      notifyListeners();
    }
  }

  Future<void> deleteTodo(String id) async {
    _todos.removeWhere((e) => e.id == id);
    await _save();
    notifyListeners();
  }
}
