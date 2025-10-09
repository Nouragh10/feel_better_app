// PATH: lib/widgets/action_timer.dart
import 'dart:async';
import 'package:flutter/material.dart';

class ActionTimer extends StatefulWidget {
  const ActionTimer({
    super.key,
    required this.initialSeconds,
    required this.options,
    required this.onComplete,
  });

  final int initialSeconds;
  final List<int> options;
  final VoidCallback onComplete;

  @override
  State<ActionTimer> createState() => _ActionTimerState();
}

class _ActionTimerState extends State<ActionTimer> {
  late int _selectedSeconds;
  late int _remaining;
  Timer? _ticker;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _selectedSeconds = widget.initialSeconds;
    _remaining = _selectedSeconds;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _start() {
    if (_running) return;
    setState(() => _running = true);
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_remaining <= 1) {
        t.cancel();
        setState(() {
          _remaining = 0;
          _running = false;
        });
        widget.onComplete();
      } else {
        setState(() => _remaining -= 1);
      }
    });
  }

  void _pause() {
    _ticker?.cancel();
    setState(() => _running = false);
  }

  void _reset() {
    // Always allowed (even while running)
    _ticker?.cancel();
    setState(() {
      _running = false;
      _remaining = _selectedSeconds;
    });
  }

  String _format(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    final ss = s.toString().padLeft(2, '0');
    return '$m:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Action timer', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),

        // Duration picker + Start/Pause + Reset
        Row(
          children: [
            // Duration
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<int>(
                value: _selectedSeconds,
                decoration: const InputDecoration(labelText: 'Duration'),
                items: widget.options
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text('${s ~/ 60} min'),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _selectedSeconds = v;
                    // If currently running, also reset remaining to the new value.
                    _remaining = v;
                    if (_running) {
                      _ticker?.cancel();
                      _running = false;
                    }
                  });
                },
              ),
            ),
            const SizedBox(width: 12),

            // Start / Pause
            Expanded(
              flex: 3,
              child: FilledButton.icon(
                onPressed: _running ? _pause : _start,
                icon: Icon(_running ? Icons.pause_rounded : Icons.play_arrow_rounded),
                label: Text(_running ? 'Pause' : 'Start'),
              ),
            ),
            const SizedBox(width: 12),

            // Reset (always enabled)
            Expanded(
              flex: 2,
              child: OutlinedButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reset'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Big countdown
        Center(
          child: Text(
            _format(_remaining),
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                ),
          ),
        ),
      ],
    );
  }
}
