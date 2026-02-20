// PATH: lib/widgets/mood_chip_selector.dart
import 'package:flutter/material.dart';

class MoodOption {
  final String label;
  final String emoji;
  final Color color;

  const MoodOption({
    required this.label,
    required this.emoji,
    required this.color,
  });
}

class MoodChipSelector extends StatefulWidget {
  const MoodChipSelector({
    super.key,
    required this.onMoodSelected,
    this.initialMood = '',
  });

  final ValueChanged<String> onMoodSelected;
  final String initialMood;

  @override
  State<MoodChipSelector> createState() => _MoodChipSelectorState();
}

class _MoodChipSelectorState extends State<MoodChipSelector>
    with SingleTickerProviderStateMixin {
  String? _selected;
  bool _showCustomField = false;
  final _customController = TextEditingController();
  late AnimationController _animController;
  late Animation<double> _expandAnimation;

  static const _moods = [
    MoodOption(label: 'anxious', emoji: '😟', color: Color(0xFF8B5CF6)),
    MoodOption(label: 'low', emoji: '😔', color: Color(0xFF6366F1)),
    MoodOption(label: 'overwhelmed', emoji: '🌀', color: Color(0xFF06B6D4)),
    MoodOption(label: 'angry', emoji: '😤', color: Color(0xFFEF4444)),
    MoodOption(label: 'tired', emoji: '😴', color: Color(0xFF64748B)),
    MoodOption(label: 'stressed', emoji: '😰', color: Color(0xFFF59E0B)),
    MoodOption(label: 'sad', emoji: '🥺', color: Color(0xFF3B82F6)),
    MoodOption(label: 'okay', emoji: '😐', color: Color(0xFF10B981)),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );

    // Pre-select if initial mood matches one of our chips
    final lower = widget.initialMood.toLowerCase();
    for (final m in _moods) {
      if (lower.contains(m.label)) {
        _selected = m.label;
        break;
      }
    }
    if (widget.initialMood.isNotEmpty && _selected == null) {
      _showCustomField = true;
      _customController.text = widget.initialMood;
      _animController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _selectMood(MoodOption mood) {
    setState(() {
      if (_selected == mood.label) {
        _selected = null;
        widget.onMoodSelected('');
      } else {
        _selected = mood.label;
        _showCustomField = false;
        _animController.reverse();
        widget.onMoodSelected('${mood.emoji} ${mood.label}');
      }
    });
  }

  void _toggleCustom() {
    setState(() {
      _showCustomField = !_showCustomField;
      if (_showCustomField) {
        _selected = null;
        _animController.forward();
      } else {
        _animController.reverse();
        _customController.clear();
        widget.onMoodSelected('');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How are you feeling right now?',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ..._moods.map((mood) {
              final isSelected = _selected == mood.label;
              return _MoodChip(
                mood: mood,
                isSelected: isSelected,
                isDark: isDark,
                onTap: () => _selectMood(mood),
              );
            }),
            // "Something else" chip
            _SomethingElseChip(
              isActive: _showCustomField,
              isDark: isDark,
              cs: cs,
              onTap: _toggleCustom,
            ),
          ],
        ),
        // Expandable custom text field
        SizeTransition(
          sizeFactor: _expandAnimation,
          child: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: TextField(
              controller: _customController,
              autofocus: true,
              textInputAction: TextInputAction.done,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Describe how you feel...',
                prefixIcon: Icon(Icons.edit_rounded, color: cs.primary),
              ),
              onChanged: (v) => widget.onMoodSelected(v.trim()),
            ),
          ),
        ),
      ],
    );
  }
}

class _MoodChip extends StatefulWidget {
  const _MoodChip({
    required this.mood,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  final MoodOption mood;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  State<_MoodChip> createState() => _MoodChipState();
}

class _MoodChipState extends State<_MoodChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.mood.color;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? color.withOpacity(widget.isDark ? 0.35 : 0.15)
                : (widget.isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.black.withOpacity(0.04)),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: widget.isSelected
                  ? color.withOpacity(0.8)
                  : (widget.isDark
                      ? Colors.white.withOpacity(0.12)
                      : Colors.black.withOpacity(0.1)),
              width: widget.isSelected ? 2 : 1.5,
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 12,
                      spreadRadius: -2,
                    )
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.mood.emoji,
                  style: TextStyle(
                      fontSize: widget.isSelected ? 20 : 18)),
              const SizedBox(width: 6),
              Text(
                widget.mood.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: widget.isSelected
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: widget.isSelected
                      ? color
                      : (widget.isDark
                          ? Colors.white.withOpacity(0.8)
                          : Colors.black.withOpacity(0.7)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SomethingElseChip extends StatelessWidget {
  const _SomethingElseChip({
    required this.isActive,
    required this.isDark,
    required this.cs,
    required this.onTap,
  });

  final bool isActive;
  final bool isDark;
  final ColorScheme cs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? cs.primary.withOpacity(isDark ? 0.25 : 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isActive
                ? cs.primary.withOpacity(0.7)
                : (isDark
                    ? Colors.white.withOpacity(0.12)
                    : Colors.black.withOpacity(0.1)),
            width: isActive ? 2 : 1.5,
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? Icons.close_rounded : Icons.add_rounded,
              size: 16,
              color: isActive
                  ? cs.primary
                  : (isDark
                      ? Colors.white.withOpacity(0.6)
                      : Colors.black.withOpacity(0.5)),
            ),
            const SizedBox(width: 6),
            Text(
              'something else',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isActive
                    ? cs.primary
                    : (isDark
                        ? Colors.white.withOpacity(0.6)
                        : Colors.black.withOpacity(0.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}