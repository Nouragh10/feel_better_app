import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class SharedActivityScreen extends StatefulWidget {
  final String chatId;
  final String activityId;
  final String activityType;
  final String friendName;

  const SharedActivityScreen({
    Key? key,
    required this.chatId,
    required this.activityId,
    required this.activityType,
    required this.friendName,
  }) : super(key: key);

  @override
  State<SharedActivityScreen> createState() => _SharedActivityScreenState();
}

class _SharedActivityScreenState extends State<SharedActivityScreen> {
  final _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  bool _friendJoined = false;
  StreamSubscription? _activitySubscription;

  @override
  void initState() {
    super.initState();
    _markAsJoined();
    _listenForFriendJoin();
  }

  @override
  void dispose() {
    _activitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _markAsJoined() async {
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('activities')
        .doc(widget.activityId)
        .update({
      'participants.$_currentUserId.joinedAt': FieldValue.serverTimestamp(),
    });
  }

  void _listenForFriendJoin() {
    _activitySubscription = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('activities')
        .doc(widget.activityId)
        .snapshots()
        .listen((snapshot) {
      final data = snapshot.data();
      if (data != null) {
        final participants = data['participants'] as Map<String, dynamic>;
        final friendData = participants.values.firstWhere(
          (p) => (p as Map<String, dynamic>)['joinedAt'] != null &&
              participants.keys.firstWhere(
                    (key) => participants[key] == p,
                  ) !=
                  _currentUserId,
          orElse: () => {'joinedAt': null},
        ) as Map<String, dynamic>;

        if (mounted) {
          setState(() {
            _friendJoined = friendData['joinedAt'] != null;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getActivityTitle()),
        actions: [
          if (_friendJoined)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Row(
                children: [
                  Icon(Icons.people, color: Colors.green),
                  SizedBox(width: 4),
                  Text('Together', style: TextStyle(color: Colors.green)),
                ],
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (!_friendJoined)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.orange.shade100,
              child: Row(
                children: [
                  const CircularProgressIndicator(strokeWidth: 2),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Waiting for ${widget.friendName} to join...',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _buildActivityContent(),
          ),
        ],
      ),
    );
  }

  String _getActivityTitle() {
    switch (widget.activityType) {
      case 'breathing':
        return 'Breathing Exercise';
      case 'yoga':
        return 'Yoga Session';
      case 'video':
        return 'Calm Video';
      default:
        return 'Activity';
    }
  }

  Widget _buildActivityContent() {
    switch (widget.activityType) {
      case 'breathing':
        return BreathingExercise(
          onComplete: _completeActivity,
          friendJoined: _friendJoined,
        );
      case 'yoga':
        return YogaSession(
          onComplete: _completeActivity,
          friendJoined: _friendJoined,
        );
      case 'video':
        return CalmVideoPlayer(
          onComplete: _completeActivity,
          friendJoined: _friendJoined,
        );
      default:
        return const Center(child: Text('Unknown activity'));
    }
  }

  Future<void> _completeActivity() async {
    Navigator.pop(context, true);
  }
}

// ============ BREATHING EXERCISE ============
class BreathingExercise extends StatefulWidget {
  final VoidCallback onComplete;
  final bool friendJoined;

  const BreathingExercise({
    Key? key,
    required this.onComplete,
    required this.friendJoined,
  }) : super(key: key);

  @override
  State<BreathingExercise> createState() => _BreathingExerciseState();
}

class _BreathingExerciseState extends State<BreathingExercise>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  String _phase = 'Breathe In';
  int _cyclesCompleted = 0;
  final int _totalCycles = 5;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _phase = 'Hold');
        _timer = Timer(const Duration(seconds: 2), () {
          setState(() => _phase = 'Breathe Out');
          _controller.reverse();
        });
      } else if (status == AnimationStatus.dismissed) {
        setState(() {
          _cyclesCompleted++;
          if (_cyclesCompleted >= _totalCycles) {
            _showCompletionDialog();
          } else {
            _phase = 'Breathe In';
            _controller.forward();
          }
        });
      }
    });

    // Auto-start after 3 seconds if friend joined
    if (widget.friendJoined) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Great job! 🎉'),
        content: const Text(
          'You completed the breathing exercise together!',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onComplete();
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Box Breathing',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Cycle ${_cyclesCompleted + 1} of $_totalCycles',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 48),
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Container(
                width: 200 * _animation.value,
                height: 200 * _animation.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.cyan.withOpacity(0.6),
                      Colors.cyan.withOpacity(0.2),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 48),
          Text(
            _phase,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.cyan,
            ),
          ),
          const SizedBox(height: 32),
          if (!widget.friendJoined)
            const Text(
              'Waiting for your friend to start...',
              style: TextStyle(color: Colors.grey),
            )
          else
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Breathing together',
                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ============ YOGA SESSION ============
class YogaSession extends StatefulWidget {
  final VoidCallback onComplete;
  final bool friendJoined;

  const YogaSession({
    Key? key,
    required this.onComplete,
    required this.friendJoined,
  }) : super(key: key);

  @override
  State<YogaSession> createState() => _YogaSessionState();
}

class _YogaSessionState extends State<YogaSession> {
  int _currentPose = 0;
  int _remainingSeconds = 30;
  Timer? _timer;

  final List<Map<String, dynamic>> _poses = [
    {
      'name': 'Mountain Pose',
      'icon': Icons.accessibility_new,
      'description': 'Stand tall with feet together, arms at sides',
      'duration': 30,
    },
    {
      'name': 'Forward Fold',
      'icon': Icons.accessibility,
      'description': 'Bend forward from hips, let head hang',
      'duration': 30,
    },
    {
      'name': 'Cat-Cow Stretch',
      'icon': Icons.self_improvement,
      'description': 'On hands and knees, arch and round your back',
      'duration': 30,
    },
    {
      'name': 'Child\'s Pose',
      'icon': Icons.airline_seat_recline_extra,
      'description': 'Knees wide, sit back on heels, arms forward',
      'duration': 30,
    },
  ];

  @override
  void initState() {
    super.initState();
    if (widget.friendJoined) {
      _startPose();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPose() {
    setState(() {
      _remainingSeconds = _poses[_currentPose]['duration'] as int;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _remainingSeconds--;
      });

      if (_remainingSeconds <= 0) {
        timer.cancel();
        if (_currentPose < _poses.length - 1) {
          setState(() {
            _currentPose++;
          });
          Future.delayed(const Duration(seconds: 2), _startPose);
        } else {
          _showCompletionDialog();
        }
      }
    });
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Namaste! 🙏'),
        content: const Text(
          'You completed the yoga session together!',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onComplete();
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pose = _poses[_currentPose];

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Gentle Yoga Flow',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Pose ${_currentPose + 1} of ${_poses.length}',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 48),
            Icon(
              pose['icon'] as IconData,
              size: 120,
              color: Colors.purple,
            ),
            const SizedBox(height: 24),
            Text(
              pose['name'] as String,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.purple,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              pose['description'] as String,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (widget.friendJoined) ...[
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.purple, width: 8),
                ),
                child: Center(
                  child: Text(
                    '$_remainingSeconds',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people, color: Colors.green),
                  SizedBox(width: 8),
                  Text(
                    'Flowing together',
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ] else
              Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text(
                    'Waiting for your friend...',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _startPose,
                    child: const Text('Start Anyway'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ============ CALM VIDEO PLAYER ============
class CalmVideoPlayer extends StatefulWidget {
  final VoidCallback onComplete;
  final bool friendJoined;

  const CalmVideoPlayer({
    Key? key,
    required this.onComplete,
    required this.friendJoined,
  }) : super(key: key);

  @override
  State<CalmVideoPlayer> createState() => _CalmVideoPlayerState();
}

class _CalmVideoPlayerState extends State<CalmVideoPlayer> {
  late YoutubePlayerController _controller;
  bool _videoWatched = false;

  // Calming video IDs (replace with your preferred videos)
  final List<String> _videoIds = [
    'lFcSrYw-ARY', // 5min meditation
    '1ZYbU82GVz4', // Ocean sounds
    'aEqlQvczMJQ', // Rain sounds
  ];

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: _videoIds.first,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
      ),
    );

    _controller.addListener(() {
      if (_controller.value.position >= _controller.metadata.duration - const Duration(seconds: 5)) {
        if (!_videoWatched) {
          setState(() => _videoWatched = true);
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!widget.friendJoined)
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.orange.shade100,
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Video will start when your friend joins',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      'Calming Video',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Watch together and relax',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              YoutubePlayer(
                controller: _controller,
                showVideoProgressIndicator: true,
              ),
              const SizedBox(height: 24),
              if (widget.friendJoined)
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people, color: Colors.green),
                    SizedBox(width: 8),
                    Text(
                      'Watching together',
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              const SizedBox(height: 24),
              if (_videoWatched)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: widget.onComplete,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Mark as Complete',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}