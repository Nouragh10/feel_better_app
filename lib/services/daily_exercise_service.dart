// PATH: lib/services/daily_exercise_service.dart
// Create this new file for managing daily exercises

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

enum ExerciseType {
  video,
  reading,
  breathing,
  gratitude,
  affirmation,
  meditation,
  movement,
  journaling,
}

class DailyExercise {
  final String id;
  final ExerciseType type;
  final String title;
  final String description;
  final String? content; // URL for video, text for reading, etc.
  final int estimatedMinutes;
  final String emoji;

  DailyExercise({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    this.content,
    required this.estimatedMinutes,
    required this.emoji,
  });
}

class DailyExerciseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String _todayKey() {
    final now = DateTime.now();
    return DateFormat('yyyy-MM-dd').format(now);
  }

  // Predefined exercises pool (rotates based on day of year)
  List<DailyExercise> _getAllExercises() {
    return [
      // Videos
      DailyExercise(
        id: 'video_1',
        type: ExerciseType.video,
        title: 'Watch: 3-Minute Motivation',
        description: 'Watch this short motivational video to start your day with energy',
        content: 'https://www.youtube.com/results?search_query=3+minute+motivational+video',
        estimatedMinutes: 3,
        emoji: '🎬',
      ),
      DailyExercise(
        id: 'video_2',
        type: ExerciseType.video,
        title: 'Watch: Nature Calm',
        description: 'Spend 2 minutes watching peaceful nature scenes',
        content: 'https://www.youtube.com/results?search_query=2+minute+calming+nature+video',
        estimatedMinutes: 2,
        emoji: '🌿',
      ),
      
      // Reading
      DailyExercise(
        id: 'reading_1',
        type: ExerciseType.reading,
        title: 'Read: Daily Wisdom',
        description: 'Read this short passage and reflect on its meaning',
        content: '"The only way to do great work is to love what you do. If you haven\'t found it yet, keep looking. Don\'t settle." - Steve Jobs\n\nReflect: What small step can you take today toward something you love?',
        estimatedMinutes: 2,
        emoji: '📖',
      ),
      DailyExercise(
        id: 'reading_2',
        type: ExerciseType.reading,
        title: 'Read: Mindful Moment',
        description: 'A quick read to center yourself',
        content: '"You are not your thoughts. You are the observer of your thoughts."\n\nTake a moment to notice what you\'re thinking right now, without judgment. Just observe.',
        estimatedMinutes: 2,
        emoji: '📚',
      ),
      
      // Breathing
      DailyExercise(
        id: 'breathing_1',
        type: ExerciseType.breathing,
        title: 'Practice: Box Breathing',
        description: 'A simple 4-4-4-4 breathing technique used by Navy SEALs',
        content: 'Inhale for 4 counts\nHold for 4 counts\nExhale for 4 counts\nHold for 4 counts\n\nRepeat 4 times',
        estimatedMinutes: 2,
        emoji: '🌬️',
      ),
      DailyExercise(
        id: 'breathing_2',
        type: ExerciseType.breathing,
        title: 'Practice: 4-7-8 Breathing',
        description: 'A calming breath technique to reduce anxiety',
        content: 'Inhale through nose for 4 counts\nHold for 7 counts\nExhale through mouth for 8 counts\n\nRepeat 3 times',
        estimatedMinutes: 2,
        emoji: '💨',
      ),
      
      // Gratitude
      DailyExercise(
        id: 'gratitude_1',
        type: ExerciseType.gratitude,
        title: 'Write: Three Good Things',
        description: 'List three things you\'re grateful for today',
        content: 'Think about:\n1. Something small (like your morning coffee)\n2. Someone who helps you\n3. Something about yourself\n\nWrite them down or say them out loud.',
        estimatedMinutes: 3,
        emoji: '🙏',
      ),
      DailyExercise(
        id: 'gratitude_2',
        type: ExerciseType.gratitude,
        title: 'Reflect: Appreciation',
        description: 'Notice one thing you usually take for granted',
        content: 'Choose something simple:\n• Running water\n• A comfortable bed\n• Your ability to read this\n\nSpend one minute appreciating it.',
        estimatedMinutes: 2,
        emoji: '✨',
      ),
      
      // Affirmation
      DailyExercise(
        id: 'affirmation_1',
        type: ExerciseType.affirmation,
        title: 'Say: Power Affirmations',
        description: 'Repeat these affirmations 3 times out loud',
        content: 'I am capable of handling today.\nI am doing my best, and that is enough.\nI choose to focus on what I can control.',
        estimatedMinutes: 2,
        emoji: '💪',
      ),
      DailyExercise(
        id: 'affirmation_2',
        type: ExerciseType.affirmation,
        title: 'Say: Self-Compassion',
        description: 'Practice kindness toward yourself',
        content: 'Place your hand on your heart and say:\n"I am worthy of love and belonging."\n"I forgive myself for being human."\n"I am enough, exactly as I am."',
        estimatedMinutes: 2,
        emoji: '❤️',
      ),
      
      // Movement
      DailyExercise(
        id: 'movement_1',
        type: ExerciseType.movement,
        title: 'Move: Gentle Stretch',
        description: 'Wake up your body with simple stretches',
        content: '1. Neck rolls (10 seconds each direction)\n2. Shoulder rolls (10 times)\n3. Reach for the sky (hold 10 seconds)\n4. Touch your toes (hold 10 seconds)\n5. Twist left and right (5 times each)',
        estimatedMinutes: 3,
        emoji: '🤸',
      ),
      DailyExercise(
        id: 'movement_2',
        type: ExerciseType.movement,
        title: 'Move: Energy Shake',
        description: 'Shake off tension and boost energy',
        content: 'Stand up and:\n1. Shake your hands for 20 seconds\n2. Shake your whole body for 20 seconds\n3. Jump lightly 10 times\n4. Take 3 deep breaths\n\nNotice how you feel!',
        estimatedMinutes: 2,
        emoji: '⚡',
      ),
      
      // Journaling
      DailyExercise(
        id: 'journaling_1',
        type: ExerciseType.journaling,
        title: 'Write: Morning Pages',
        description: 'Quick brain dump to clear your mind',
        content: 'Set a timer for 2 minutes.\nWrite whatever comes to mind.\nDon\'t stop, don\'t edit, just write.\nLet it all out onto paper (or notes app).',
        estimatedMinutes: 3,
        emoji: '✍️',
      ),
      DailyExercise(
        id: 'journaling_2',
        type: ExerciseType.journaling,
        title: 'Write: One Sentence',
        description: 'Capture today in a single sentence',
        content: 'Complete this sentence:\n"Today, I want to feel _______"\n\nor\n\n"Today, I am proud that I _______"',
        estimatedMinutes: 2,
        emoji: '📝',
      ),
    ];
  }

  // Get today's exercise (deterministic based on day of year)
  DailyExercise getTodayExercise() {
    final exercises = _getAllExercises();
    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    final index = dayOfYear % exercises.length;
    return exercises[index];
  }

  // Check if user completed today's exercise
  Future<bool> hasCompletedToday(String uid) async {
    final today = _todayKey();
    try {
      final doc = await _db
          .collection('daily_exercises')
          .doc(uid)
          .collection('completions')
          .doc(today)
          .get();
      return doc.exists && (doc.data()?['completed'] == true);
    } catch (_) {
      return false;
    }
  }

  // Mark today's exercise as complete
  Future<void> completeToday(String uid) async {
    final today = _todayKey();
    final exercise = getTodayExercise();
    
    await _db
        .collection('daily_exercises')
        .doc(uid)
        .collection('completions')
        .doc(today)
        .set({
      'completed': true,
      'exerciseId': exercise.id,
      'exerciseType': exercise.type.toString(),
      'completedAt': FieldValue.serverTimestamp(),
      'dayKey': today,
    });

    // Update user's daily streak
    await _updateDailyStreak(uid, today);
  }

  Future<void> _updateDailyStreak(String uid, String dayKey) async {
    final userRef = _db.collection('users').doc(uid);
    
    await _db.runTransaction((tx) async {
      final snap = await tx.get(userRef);
      final data = snap.data() ?? {};
      
      final lastDayKey = data['dailyLastDayKey'] as String?;
      final currentStreak = (data['dailyCurrentStreak'] as int?) ?? 0;
      final longestStreak = (data['dailyLongestStreak'] as int?) ?? 0;

      int nextStreak;
      if (lastDayKey == null) {
        nextStreak = 1;
      } else if (lastDayKey == dayKey) {
        nextStreak = currentStreak; // Already counted today
      } else {
        final prev = DateTime.parse(lastDayKey);
        final cur = DateTime.parse(dayKey);
        final consecutive = cur.difference(prev).inDays == 1;
        nextStreak = consecutive ? currentStreak + 1 : 1;
      }

      tx.set(userRef, {
        'dailyLastDayKey': dayKey,
        'dailyCurrentStreak': nextStreak,
        'dailyLongestStreak': (nextStreak > longestStreak) ? nextStreak : longestStreak,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  // Get user's completion history (last 30 days)
  Future<List<String>> getCompletionHistory(String uid, {int days = 30}) async {
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days));
    
    final snapshot = await _db
        .collection('daily_exercises')
        .doc(uid)
        .collection('completions')
        .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .get();

    return snapshot.docs.map((doc) => doc.id).toList();
  }
}