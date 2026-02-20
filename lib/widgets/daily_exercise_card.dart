// PATH: lib/widgets/daily_exercise_card.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/daily_exercise_service.dart';
import '../services/firestore_service.dart';
import '../screens/settings_screen.dart' show ghostMode;
import 'confetti_overlay.dart';

class DailyExerciseCard extends StatefulWidget {
  const DailyExerciseCard({super.key});

  @override
  State<DailyExerciseCard> createState() => _DailyExerciseCardState();
}

class _DailyExerciseCardState extends State<DailyExerciseCard>
    with SingleTickerProviderStateMixin {
  final _service = DailyExerciseService();
  bool _loading = true;
  bool _completed = false;
  late DailyExercise _todayExercise;
  int _currentStreak = 0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadToday();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadToday() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    final completed = await _service.hasCompletedToday(uid);
    final exercise = _service.getTodayExercise();

    // Load streak from Firestore
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      _currentStreak = (snap.data()?['dailyCurrentStreak'] as int?) ?? 0;
    } catch (_) {}

    setState(() {
      _completed = completed;
      _todayExercise = exercise;
      _loading = false;
    });

    if (!_completed) _pulseController.repeat(reverse: true);
  }

  String _streakMessage() {
    if (_currentStreak == 0) return 'Start your streak today! 🌱';
    if (_currentStreak == 1) return '1-day streak — keep it going! 🔥';
    if (_currentStreak < 7) return '$_currentStreak-day streak — don\'t break it! 🔥';
    if (_currentStreak < 14) return '$_currentStreak days strong! You\'re on fire 🔥🔥';
    if (_currentStreak < 30) return '$_currentStreak days! Incredible consistency 🔥🔥🔥';
    return '$_currentStreak days! You\'re unstoppable 🏆';
  }

  Future<void> _viewExercise() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DailyExerciseScreen(exercise: _todayExercise),
      ),
    );

    if (result == true) {
      setState(() {
        _completed = true;
        _currentStreak += 1;
        _pulseController.stop();
      });
      // Show confetti on streak milestones
      if (_currentStreak % 3 == 0 || _currentStreak == 1) {
        if (mounted) ConfettiOverlay.show(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return Container(
        height: 100,
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.04)
              : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final scale = _completed ? 1.0 : _pulseAnimation.value;
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _completed
                ? [
                    cs.surfaceVariant.withOpacity(0.5),
                    cs.surfaceVariant.withOpacity(0.3),
                  ]
                : [
                    const Color(0xFF06B6D4).withOpacity(isDark ? 0.2 : 0.12),
                    const Color(0xFF8B5CF6).withOpacity(isDark ? 0.2 : 0.12),
                  ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _completed
                ? cs.outline.withOpacity(0.2)
                : cs.primary.withOpacity(0.5),
            width: _completed ? 1.5 : 2,
          ),
          boxShadow: _completed
              ? []
              : [
                  BoxShadow(
                    color: cs.primary.withOpacity(0.15),
                    blurRadius: 20,
                    spreadRadius: -4,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _completed ? null : _viewExercise,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Emoji icon
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: _completed
                              ? null
                              : LinearGradient(
                                  colors: [cs.primary, cs.secondary],
                                ),
                          color: _completed ? cs.surfaceVariant : null,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            _completed ? '✅' : _todayExercise.emoji,
                            style: const TextStyle(fontSize: 26),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _completed
                                        ? cs.surfaceVariant
                                        : cs.primary.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _completed
                                        ? 'Done today ✓'
                                        : 'Daily Exercise',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: _completed
                                          ? cs.onSurfaceVariant
                                          : cs.primary,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _completed
                                  ? _todayExercise.title
                                  : 'Complete your daily task!',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(Icons.timer_outlined,
                                    size: 13,
                                    color: cs.onSurface.withOpacity(0.5)),
                                const SizedBox(width: 3),
                                Text(
                                  '${_todayExercise.estimatedMinutes} min',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurface.withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _completed
                            ? Icons.check_circle_rounded
                            : Icons.arrow_forward_rounded,
                        color: _completed ? Colors.green : cs.primary,
                        size: 26,
                      ),
                    ],
                  ),
                  // Streak bar
                  const SizedBox(height: 14),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Text('🔥', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _streakMessage(),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface.withOpacity(0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// DAILY EXERCISE FULL SCREEN
// ============================================================================
class DailyExerciseScreen extends StatefulWidget {
  final DailyExercise exercise;

  const DailyExerciseScreen({super.key, required this.exercise});

  @override
  State<DailyExerciseScreen> createState() => _DailyExerciseScreenState();
}

class _DailyExerciseScreenState extends State<DailyExerciseScreen> {
  final _service = DailyExerciseService();
  bool _completing = false;

  Future<void> _completeExercise() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _completing = true);

    try {
      await _service.completeToday(uid);

      if (!ghostMode.value) {
        try {
          final fs = FirestoreService();
          final entryId = await fs.addExerciseCompletionEntry(
            uid: uid,
            exerciseTitle: widget.exercise.title,
            exerciseType: widget.exercise.type.toString(),
            shareWithFriends: true,
            createdAtLocal: DateTime.now(),
          );
          await fs.mirrorPublicEntry(
            entryId: entryId,
            authorId: uid,
            publicSummary:
                'completed today\'s exercise: ${widget.exercise.title}',
          );
          try {
            final userSnap = await fs.getUser(uid);
            final userData = userSnap.data();
            final username =
                userData?['username'] as String? ?? 'Someone';
            await fs.notifyTrustedPerson(
              fromUid: uid,
              fromUsername: username,
              summary:
                  'completed today\'s exercise: ${widget.exercise.title}',
            );
          } catch (_) {}
        } catch (_) {}
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.celebration_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  ghostMode.value
                      ? 'Great job! Your streak has been updated 🔥'
                      : 'Great job! Shared with friends 🔥',
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not complete: $e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
      setState(() => _completing = false);
    }
  }

  Future<void> _openLink() async {
    if (widget.exercise.content == null) return;
    final uri = Uri.parse(widget.exercise.content!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Daily Exercise'),
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [
                    Color(0xFF0B1120),
                    Color(0xFF0F172A),
                    Color(0xFF1E293B)
                  ]
                : const [
                    Color(0xFFF0F9FF),
                    Color(0xFFFAFAFF),
                    Color(0xFFFFFFFF)
                  ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        cs.primary.withOpacity(0.15),
                        cs.secondary.withOpacity(0.15)
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: cs.primary.withOpacity(0.3), width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(widget.exercise.emoji,
                              style: const TextStyle(fontSize: 48)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Today's Exercise",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: cs.primary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.exercise.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                          fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.timer_outlined,
                                size: 16,
                                color: cs.onPrimaryContainer),
                            const SizedBox(width: 6),
                            Text(
                              '${widget.exercise.estimatedMinutes} minutes',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: cs.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  widget.exercise.description,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 16,
                      color: cs.onSurface.withOpacity(0.8)),
                ),
                const SizedBox(height: 32),
                if (widget.exercise.content != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: cs.outline.withOpacity(0.2)),
                    ),
                    child: widget.exercise.type == ExerciseType.video
                        ? Column(
                            children: [
                              Icon(Icons.play_circle_outline,
                                  size: 64, color: cs.primary),
                              const SizedBox(height: 16),
                              Text(
                                'Tap below to watch the video',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: cs.onSurface.withOpacity(0.6),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: _openLink,
                                icon: const Icon(Icons.open_in_new_rounded),
                                label: const Text('Open Video'),
                              ),
                            ],
                          )
                        : Text(
                            widget.exercise.content!,
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      fontSize: 15,
                                      height: 1.8,
                                      color: cs.onSurface,
                                    ),
                          ),
                  ),
                  const SizedBox(height: 32),
                ],
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: cs.onSecondaryContainer, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Complete the exercise, then tap "I Did It!" to update your streak.',
                          style: TextStyle(
                              fontSize: 13,
                              color: cs.onSecondaryContainer),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: _completing ? null : _completeExercise,
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.secondary,
                      foregroundColor: cs.onSecondary,
                    ),
                    icon: _completing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_rounded),
                    label: Text(_completing
                        ? 'Saving...'
                        : 'I Did It! 🎉'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}