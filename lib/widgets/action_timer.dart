// PATH: lib/widgets/action_timer.dart
import 'dart:async';
import 'package:flutter/material.dart';

class ActionTimer extends StatefulWidget {
  const ActionTimer({
    super.key,
    this.initialSeconds = 60,
    this.options = const [60, 120, 300],
    this.onComplete,
  });

  final int initialSeconds;
  final List<int> options;
  final VoidCallback? onComplete;

  @override
  State<ActionTimer> createState() => _ActionTimerState();
}

class _ActionTimerState extends State<ActionTimer> {
  Timer? _timer;
  late int _selectedSeconds;
  late int _remainingSeconds;
  bool _isTicking = false;

  @override
  void initState() {
    super.initState();
    _selectedSeconds = widget.initialSeconds;
    _remainingSeconds = widget.initialSeconds;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _applySelectedDuration(int secs) {
    _timer?.cancel();
    setState(() {
      _selectedSeconds = secs;
      _remainingSeconds = secs;
      _isTicking = false;
    });
  }

  void _toggleStartPause() {
    if (_isTicking) {
      _timer?.cancel();
      setState(() => _isTicking = false);
      return;
    }
    if (_remainingSeconds <= 0) {
      _remainingSeconds = _selectedSeconds;
    }
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        t.cancel();
        setState(() {
          _remainingSeconds = 0;
          _isTicking = false;
        });
        widget.onComplete?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Time's up — nice job.")),
        );
      } else {
        setState(() => _remainingSeconds -= 1);
      }
    });
    setState(() => _isTicking = true);
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _remainingSeconds = _selectedSeconds;
      _isTicking = false;
    });
  }

  String _fmt(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$m:$ss';
  }

  double _progress() {
    if (_selectedSeconds <= 0) return 0;
    final done = _selectedSeconds - _remainingSeconds;
    final p = done / _selectedSeconds;
    if (p.isNaN) return 0;
    return p.clamp(0, 1);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Action timer', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Row(
            children: [
              // duration picker
              DropdownButton<int>(
                value: _selectedSeconds,
                items: widget.options
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s == 60
                              ? '1 min'
                              : s == 120
                                  ? '2 min'
                                  : '${s ~/ 60} min'),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  _applySelectedDuration(v);
                },
              ),
              const SizedBox(width: 12),

              // start / pause
              FilledButton.icon(
                onPressed: _toggleStartPause,
                icon: Icon(
                  _isTicking ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
                label: Text(_isTicking ? 'Pause' : 'Start'),
              ),
              const SizedBox(width: 8),

              // reset
              OutlinedButton.icon(
                onPressed: _resetTimer,
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Reset'),
              ),

              const Spacer(),

              // countdown & progress
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _fmt(_remainingSeconds),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 180,
                    child: LinearProgressIndicator(
                      value: _progress(),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
