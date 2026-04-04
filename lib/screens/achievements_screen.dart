import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/achievement_provider.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isSharing = false;

  Future<void> _shareAchievements() async {
    setState(() {
      _isSharing = true;
    });

    try {
      final image = await _screenshotController.capture(
        delay: const Duration(milliseconds: 10),
      );
      if (image != null) {
        final directory = await getApplicationDocumentsDirectory();
        final imagePath = await File(
          '${directory.path}/achievements.png',
        ).create();
        await imagePath.writeAsBytes(image);

        await Share.shareXFiles([
          XFile(imagePath.path),
        ], text: 'Check out my Calcdence achievements! 🔥');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing achievements: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trophy Room'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          if (_isSharing)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.0,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _shareAchievements,
            ),
        ],
      ),
      body: Consumer<AchievementProvider>(
        builder: (context, achievementProv, child) {
          final badges = achievementProv.allBadges;
          final unlocked = achievementProv.unlockedBadgeIds;
          final streak = achievementProv.currentStreak;

          return Screenshot(
            controller: _screenshotController,
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  _buildStreakCard(streak),
                  const SizedBox(height: 24),
                  Text(
                    'Badges',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: badges.length,
                    itemBuilder: (context, index) {
                      final badge = badges[index];
                      final isUnlocked = unlocked.contains(badge.id);
                      return _buildBadgeCard(badge, isUnlocked);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStreakCard(int streak) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Colors.deepOrange, Colors.orangeAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.local_fire_department,
              size: 64,
              color: Colors.white,
            ),
            const SizedBox(height: 8),
            Text(
              '$streak Day Streak',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              streak > 0
                  ? "You're on fire! Keep it up."
                  : "Start attending classes to build your streak!",
              style: const TextStyle(fontSize: 16, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeCard(AchievementBadge badge, bool isUnlocked) {
    return Card(
      elevation: isUnlocked ? 4 : 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isUnlocked ? null : Colors.grey.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isUnlocked
                    ? Color(badge.colorValue).withOpacity(0.2)
                    : Colors.grey.withOpacity(0.2),
              ),
              child: Icon(
                badge.iconData,
                size: 40,
                color: isUnlocked ? Color(badge.colorValue) : Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              badge.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isUnlocked ? null : Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                badge.description,
                style: TextStyle(
                  fontSize: 12,
                  color: isUnlocked ? Colors.black87 : Colors.grey,
                ),
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
