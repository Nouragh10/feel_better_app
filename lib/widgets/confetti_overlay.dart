// PATH: lib/widgets/confetti_overlay.dart
//
// Self-contained confetti implementation — no external package needed.
// Call ConfettiOverlay.show(context) to trigger a burst.
//
import 'dart:math';
import 'package:flutter/material.dart';

class _Particle {
  Offset position;
  Offset velocity;
  Color color;
  double size;
  double rotation;
  double rotationSpeed;
  double opacity;
  bool isCircle;

  _Particle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
    required this.isCircle,
  }) : opacity = 1.0;
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;

  _ConfettiPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final paint = Paint()..color = p.color.withOpacity(p.opacity);
      canvas.save();
      canvas.translate(p.position.dx, p.position.dy);
      canvas.rotate(p.rotation);
      if (p.isCircle) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
              center: Offset.zero, width: p.size, height: p.size * 0.5),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => true;
}

class _ConfettiWidget extends StatefulWidget {
  final VoidCallback onComplete;

  const _ConfettiWidget({required this.onComplete});

  @override
  State<_ConfettiWidget> createState() => _ConfettiWidgetState();
}

class _ConfettiWidgetState extends State<_ConfettiWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];
  final _random = Random();

  static const _colors = [
    Color(0xFF06B6D4),
    Color(0xFF8B5CF6),
    Color(0xFFFF6B9D),
    Color(0xFFFBBF24),
    Color(0xFF10B981),
    Color(0xFFF97316),
    Color(0xFFEC4899),
    Color(0xFF3B82F6),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..addListener(_update)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onComplete();
      });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _spawnParticles();
      _controller.forward();
    });
  }

  void _spawnParticles() {
    final size = MediaQuery.of(context).size;
    final cx = size.width / 2;

    for (int i = 0; i < 90; i++) {
      final angle = (_random.nextDouble() * pi) - (pi / 2) +
          (_random.nextDouble() - 0.5) * pi;
      final speed = 4 + _random.nextDouble() * 10;
      _particles.add(_Particle(
        position: Offset(cx + (_random.nextDouble() - 0.5) * 80, 80),
        velocity: Offset(cos(angle) * speed, sin(angle) * speed - 8),
        color: _colors[_random.nextInt(_colors.length)],
        size: 6 + _random.nextDouble() * 10,
        rotation: _random.nextDouble() * pi * 2,
        rotationSpeed: (_random.nextDouble() - 0.5) * 0.3,
        isCircle: _random.nextBool(),
      ));
    }
  }

  void _update() {
    if (!mounted) return;
    setState(() {
      for (final p in _particles) {
        p.velocity = Offset(p.velocity.dx * 0.98, p.velocity.dy + 0.4);
        p.position += p.velocity;
        p.rotation += p.rotationSpeed;
        p.opacity = (1.0 - _controller.value * 0.8).clamp(0.0, 1.0);
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
    return IgnorePointer(
      child: CustomPaint(
        painter: _ConfettiPainter(_particles),
        size: Size.infinite,
      ),
    );
  }
}

class ConfettiOverlay {
  static OverlayEntry? _entry;

  static void show(BuildContext context) {
    _entry?.remove();
    _entry = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: _ConfettiWidget(
          onComplete: () {
            _entry?.remove();
            _entry = null;
          },
        ),
      ),
    );
    Overlay.of(context).insert(_entry!);
  }
}