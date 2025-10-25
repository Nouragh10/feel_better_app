// PATH: lib/screens/shared_exercise_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/action_timer.dart';

class SharedExerciseScreen extends StatefulWidget {
  const SharedExerciseScreen({
    super.key,
    required this.chatId,
    required this.activityId,
    required this.exerciseType,
    required this.partnerName,
  });

  final String chatId;
  final String activityId;
  final String exerciseType; // 'breathing' | 'yoga' | 'calm_video'
  final String partnerName;

  @override
  State<SharedExerciseScreen> createState() => _SharedExerciseScreenState();
}

class _SharedExerciseScreenState extends State<SharedExerciseScreen> {
  bool _completing = false;

  int get _initialSeconds => switch (widget.exerciseType) {
        'breathing' => 120,
        'yoga' => 300,
        'calm_video' => 180,
        _ => 180,
      };

  List<int> get _options => switch (widget.exerciseType) {
        'breathing' => const [120, 180, 300],
        'yoga' => const [300, 420, 600],
        'calm_video' => const [180, 240, 300],
        _ => const [180, 240, 300],
      };

  String get _title => switch (widget.exerciseType) {
        'breathing' => 'Breathing Exercise',
        'yoga' => 'Yoga Session',
        'calm_video' => 'Calm Video',
        _ => 'Exercise',
      };

  String get _emoji => switch (widget.exerciseType) {
        'breathing' => '🫁',
        'yoga' => '🧘‍♀️',
        'calm_video' => '🎧',
        _ => '✨',
      };

  String get _instructions => switch (widget.exerciseType) {
        'breathing' =>
            "We'll do a simple 4-4-4-4 box breath together.\n\n"
            "• Inhale through your nose for 4 counts\n"
            "• Hold for 4\n"
            "• Exhale through your mouth for 4\n"
            "• Hold for 4\n\n"
            "Repeat gently. If anything feels uncomfortable, return to natural breathing.",
        'yoga' =>
            "We'll flow through a gentle mini-sequence:\n\n"
            "• Neck rolls (30s)\n"
            "• Shoulder circles (30s)\n"
            "• Cat/Cow (1 min)\n"
            "• Child's Pose (1 min)\n"
            "• Seated forward fold (1 min)\n\n"
            "Move within your comfort. Stop if you feel any pain.",
        'calm_video' =>
            "We'll watch a short calming clip together.\n\n"
            "• Settle into a comfy position\n"
            "• Let your shoulders drop\n"
            "• Notice one soothing detail in the video: colors, sounds, or pace\n\n"
            "Breathe slowly as you watch.",
        _ =>
            "Do this short exercise at a gentle pace. You can finish early if needed.",
      };

  Future<void> _complete() async {
    if (_completing) return;
    setState(() => _completing = true);
    try {
      if (!mounted) return;
      Navigator.of(context).pop(true); // tell ChatScreen that we completed
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  Future<void> _openVideo() async {
    // Generate a search URL for calming video
    final query = 'calming video 3 minutes meditation relaxing';
    final url = 'https://www.youtube.com/results?search_query=${Uri.encodeComponent(query)}';
    
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not open video'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('$_title with ${widget.partnerName}'),
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF0B1120), Color(0xFF0F172A), Color(0xFF1E293B)]
                : const [Color(0xFFF0F9FF), Color(0xFFFAFAFF), Color(0xFFFFFFFF)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [cs.primary.withOpacity(0.15), cs.secondary.withOpacity(0.15)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: cs.primary.withOpacity(0.3), width: 2),
                  ),
                  child: Row(
                    children: [
                      Text(_emoji, style: const TextStyle(fontSize: 42)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Together with ${widget.partnerName}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: cs.primary,
                                  letterSpacing: 0.5,
                                )),
                            const SizedBox(height: 4),
                            Text(_title,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    )),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  _instructions,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 16,
                        color: cs.onSurface.withOpacity(0.85),
                      ),
                ),

                const SizedBox(height: 24),

                // Video link button for calm_video type
                if (widget.exerciseType == 'calm_video') ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _openVideo,
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.tertiary,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                      ),
                      icon: const Icon(Icons.play_circle_outline_rounded, size: 24),
                      label: const Text('Watch Calming Video', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: cs.onSecondaryContainer, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Finish the timer (optional) and tap "I Completed This" to mark your part done.',
                          style: TextStyle(fontSize: 13, color: cs.onSecondaryContainer),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Shared timer (local for the user)
                ActionTimer(
                  initialSeconds: _initialSeconds,
                  options: _options,
                  onComplete: () {}, // timer completion is optional; completion is via button below
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: _completing ? null : _complete,
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.secondary,
                      foregroundColor: cs.onSecondary,
                    ),
                    icon: _completing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_rounded),
                    label: Text(_completing ? 'Completing...' : 'I Completed This'),
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