// PATH: lib/screens/shared_exercise_screen.dart (NEW)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class SharedExerciseScreen extends StatefulWidget {
  final String chatId;
  final String activityId;
  final String exerciseType; // breathing, yoga, calm_video
  final String friendName;

  const SharedExerciseScreen({
    Key? key,
    required this.chatId,
    required this.activityId,
    required this.exerciseType,
    required this.friendName,
  }) : super(key: key);

  @override
  State<SharedExerciseScreen> createState() => _SharedExerciseScreenState();
}

class _SharedExerciseScreenState extends State<SharedExerciseScreen>
    with SingleTickerProviderStateMixin {
  late int _totalSeconds;
  late int _remainingSeconds;
  Timer? _timer;
  bool _isRunning = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _setExerciseDuration();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  void _setExerciseDuration() {
    switch (widget.exerciseType) {
      case 'breathing':
        _totalSeconds = 120; // 2 minutes
        break;
      case 'yoga':
        _totalSeconds = 300; // 5 minutes
        break;
      case 'calm_video':
        _totalSeconds = 180; // 3 minutes
        break;
      default:
        _totalSeconds = 120;
    }
    _remainingSeconds = _totalSeconds;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startTimer() {
    if (_isRunning) return;
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() => _isRunning = false);
        _showCompletionDialog();
      } else {
        setState(() => _remainingSeconds -= 1);
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _remainingSeconds = _totalSeconds;
    });
  }

  void _completeExercise() {
    Navigator.pop(context, true);
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.green.withOpacity(0.1),
                Colors.blue.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.celebration_rounded, size: 64, color: Colors.green),
              const SizedBox(height: 24),
              const Text(
                'Excellent Work!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'You completed the exercise! Your friend can still finish.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _completeExercise();
                  },
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Widget _buildExerciseContent() {
    switch (widget.exerciseType) {
      case 'breathing':
        return _buildBreathingExercise();
      case 'yoga':
        return _buildYogaExercise();
      case 'calm_video':
        return _buildCalmVideoExercise();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBreathingExercise() {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Colors.cyan, Colors.blue],
            ),
          ),
          child: const Center(
            child: Icon(Icons.air_rounded, size: 64, color: Colors.white),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Box Breathing',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          'Inhale 4 seconds • Hold 4 seconds\nExhale 4 seconds • Hold 4 seconds',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.6),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.cyan.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(
                'Breathing Cycle',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.cyan.shade800,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Follow your breath:\n'
                '1. Inhale through your nose for 4 counts\n'
                '2. Hold your breath for 4 counts\n'
                '3. Exhale through your mouth for 4 counts\n'
                '4. Hold for 4 counts\n\n'
                'Repeat this cycle during the timer',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.6),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildYogaExercise() {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Colors.purple, Colors.indigo],
            ),
          ),
          child: const Center(
            child: Icon(Icons.self_improvement_rounded, size: 64, color: Colors.white),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Gentle Yoga Flow',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          '5-minute guided session',
          style: TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(
                'Yoga Poses',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.purple.shade800,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '• Child\'s Pose - 1 minute (rest & relax)\n'
                '• Cat-Cow Stretch - 1 minute (warm up)\n'
                '• Downward Dog - 1 minute (energize)\n'
                '• Warrior Pose - 1 minute (strengthen)\n'
                '• Corpse Pose - 1 minute (cool down)\n\n'
                'Move gently and breathe deeply',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.6),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCalmVideoExercise() {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Colors.orange, Colors.amber],
            ),
          ),
          child: const Center(
            child: Icon(Icons.play_circle_outline_rounded, size: 64, color: Colors.white),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Guided Meditation',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          '3-minute calm video',
          style: TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(
                'Video Instructions',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade800,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '• Find a comfortable seated position\n'
                '• Close your eyes if comfortable\n'
                '• Listen to the guided meditation\n'
                '• Follow along with the breathing cues\n'
                '• Feel your body relax and calm\n\n'
                'Watch a YouTube video on meditation',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.6),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shared Exercise'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Exercise instructions
              _buildExerciseContent(),

              const SizedBox(height: 48),

              // Friend status
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.people_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Doing this together',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            widget.friendName,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              // Large timer display
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      cs.primary.withOpacity(0.2),
                      cs.secondary.withOpacity(0.2),
                    ],
                  ),
                  border: Border.all(
                    color: cs.primary,
                    width: 3,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _formatTime(_remainingSeconds),
                        style: const TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'remaining',
                        style: TextStyle(
                          fontSize: 14,
                          color: cs.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 48),

              // Timer controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Start / Pause button
                  FloatingActionButton.large(
                    onPressed: _isRunning ? _pauseTimer : _startTimer,
                    child: Icon(_isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded),
                  ),
                  const SizedBox(width: 16),
                  // Reset button
                  FloatingActionButton.large(
                    backgroundColor: cs.surfaceVariant,
                    foregroundColor: cs.onSurfaceVariant,
                    onPressed: _resetTimer,
                    child: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Complete button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _completeExercise,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text(
                    'I Completed This Exercise',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Close button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Exit Without Completing'),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}