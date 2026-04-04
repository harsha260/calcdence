import 'dart:convert';

class TodoItem {
  final String id;
  final String title;
  final bool isDone;
  final int? subjectId;
  final String? subjectName;
  final DateTime? startTime;
  final DateTime? endTime;
  final DateTime? notificationTime;
  final int? notificationId;

  TodoItem({
    required this.id,
    required this.title,
    this.isDone = false,
    this.subjectId,
    this.subjectName,
    this.startTime,
    this.endTime,
    this.notificationTime,
    this.notificationId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'isDone': isDone,
        'subjectId': subjectId,
        'subjectName': subjectName,
        'startTime': startTime?.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'notificationTime': notificationTime?.toIso8601String(),
        'notificationId': notificationId,
      };

  factory TodoItem.fromJson(Map<String, dynamic> json) => TodoItem(
        id: json['id'],
        title: json['title'],
        isDone: json['isDone'] ?? false,
        subjectId: json['subjectId'],
        subjectName: json['subjectName'],
        startTime: json['startTime'] != null
            ? DateTime.tryParse(json['startTime'])
            : null,
        endTime: json['endTime'] != null
            ? DateTime.tryParse(json['endTime'])
            : (json['dueDate'] != null
                ? DateTime.tryParse(json['dueDate'])
                : null),
        notificationTime: json['notificationTime'] != null
            ? DateTime.tryParse(json['notificationTime'])
            : null,
        notificationId: json['notificationId'],
      );

  TodoItem copyWith({
    String? title,
    bool? isDone,
    int? subjectId,
    String? subjectName,
    DateTime? startTime,
    DateTime? endTime,
    DateTime? notificationTime,
    int? notificationId,
  }) {
    return TodoItem(
      id: id,
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
      subjectId: subjectId ?? this.subjectId,
      subjectName: subjectName ?? this.subjectName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      notificationTime: notificationTime ?? this.notificationTime,
      notificationId: notificationId ?? this.notificationId,
    );
  }
}
