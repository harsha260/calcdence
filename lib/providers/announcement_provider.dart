import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class Announcement {
  final String id;
  final String title;
  final String content;
  final DateTime date;
  final String? author;

  Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    this.author,
  });
}

class AnnouncementProvider extends ChangeNotifier {
  final CampXApiService _apiService = CampXApiService();
  List<Announcement> _announcements = [];
  bool _isLoading = false;

  List<Announcement> get announcements => _announcements;
  bool get isLoading => _isLoading;

  Future<void> fetchAnnouncements() async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _apiService.getAnnouncements();
      _announcements = data.map((json) {
        final authorObj = json['author'];
        final authorName = authorObj is Map ? authorObj['name'] : (json['authorName'] ?? 'College');
        
        return Announcement(
          id: (json['_id'] ?? json['id']).toString(),
          title: (json['title'] ?? 'Notice').toString(),
          content: (json['feedText'] ?? json['content'] ?? json['description'] ?? '').toString(),
          date: DateTime.tryParse(json['createdAt'] ?? json['date'] ?? '') ?? DateTime.now(),
          author: authorName?.toString(),
        );
      }).toList();
    } catch (e) {
      print('Error fetching announcements: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
