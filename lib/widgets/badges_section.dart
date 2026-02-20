// PATH: lib/widgets/badges_section.dart
//
// A self-contained badges display widget. Drop into ProfileScreen.
// Badges are earned based on Firestore data — no extra collections needed,
// all logic reads from the existing `users` document fields.
//
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class _BadgeDef {
  final String id;
  final String emoji;
  final String title;
  final String description;
  final Color color;

  const _BadgeDef({
    required this.id,
    required this.emoji,
    required this.title,
    required this.description,
    required this.color,
  });
}

const _allBadges = [
  _BadgeDef(
    id: 'first_checkin',
    emoji: '🌱',
    title: 'First Step',
    description: 'Completed your first check-in',
    color: Color(0xFF10B981),
  ),
  _BadgeDef(
    id: 'streak_3',
    emoji: '🔥',
    title: '3-Day Streak',
    description: 'Used Nearby 3 days in a row',
    color: Color(0xFFF59E0B),
  ),
  _BadgeDef(
    id: 'streak_7',
    emoji: '🌟',
    title: 'Week Warrior',
    description: '7-day streak achieved',
    color: Color(0xFF8B5CF6),
  ),
  _BadgeDef(
    id: 'streak_14',
    emoji: '💎',
    title: 'Two Weeks Strong',
    description: '14-day streak achieved',
    color: Color(0xFF06B6D4),
  ),
  _BadgeDef(
    id: 'first_share',
    emoji: '💙',
    title: 'Open Heart',
    description: 'Shared your first moment with friends',
    color: Color(0xFF3B82F6),
  ),
  _BadgeDef(
    id: 'trusted_person',
    emoji: '🤝',
    title: 'Connected',
    description: 'Added a trusted person',
    color: Color(0xFFFF6B9D),
  ),
];

class BadgesSection extends StatelessWidget {
  const BadgesSection({super.key});

  Future<Set<String>> _getEarnedBadges() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return {};

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = snap.data() ?? {};

      final earned = <String>{};
      final streak = (data['dailyCurrentStreak'] as int?) ?? 0;
      final prefs =
          (data['personalPreferences'] as Map<String, dynamic>?) ?? {};

      // Derive badges from existing data fields
      if (streak >= 1) earned.add('first_checkin');
      if (streak >= 3) earned.add('streak_3');
      if (streak >= 7) earned.add('streak_7');
      if (streak >= 14) earned.add('streak_14');
      if (prefs['trustedPerson'] != null &&
          (prefs['trustedPerson'] as String).isNotEmpty) {
        earned.add('trusted_person');
      }

      // Check if user has ever shared (look for public entries)
      final publicSnap = await FirebaseFirestore.instance
          .collection('entries_public')
          .where('authorId', isEqualTo: uid)
          .limit(1)
          .get();
      if (publicSnap.docs.isNotEmpty) earned.add('first_share');

      return earned;
    } catch (_) {
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<Set<String>>(
      future: _getEarnedBadges(),
      builder: (context, snap) {
        final earned = snap.data ?? {};

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [cs.primary, cs.secondary]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.emoji_events_rounded,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  'Badges',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${earned.length}/${_allBadges.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.9,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _allBadges.length,
              itemBuilder: (context, i) {
                final badge = _allBadges[i];
                final isEarned = earned.contains(badge.id);
                return _BadgeTile(
                  badge: badge,
                  isEarned: isEarned,
                  isDark: isDark,
                  cs: cs,
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({
    required this.badge,
    required this.isEarned,
    required this.isDark,
    required this.cs,
  });

  final _BadgeDef badge;
  final bool isEarned;
  final bool isDark;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isEarned ? badge.description : 'Not yet earned',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isEarned
              ? badge.color.withOpacity(isDark ? 0.2 : 0.1)
              : (isDark
                  ? Colors.white.withOpacity(0.04)
                  : Colors.black.withOpacity(0.03)),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isEarned
                ? badge.color.withOpacity(0.5)
                : (isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.06)),
            width: isEarned ? 2 : 1.5,
          ),
          boxShadow: isEarned
              ? [
                  BoxShadow(
                    color: badge.color.withOpacity(0.2),
                    blurRadius: 12,
                    spreadRadius: -3,
                  )
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isEarned ? badge.emoji : '🔒',
              style: TextStyle(
                  fontSize: isEarned ? 28 : 22,
                  color: isEarned ? null : Colors.grey),
            ),
            const SizedBox(height: 6),
            Text(
              badge.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isEarned
                    ? badge.color
                    : cs.onSurface.withOpacity(0.35),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}