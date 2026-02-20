// PATH: lib/widgets/nearby_items_input.dart
import 'package:flutter/material.dart';

class NearbyItemsInput extends StatefulWidget {
  const NearbyItemsInput({
    super.key,
    required this.onChanged,
    this.initialValue = '',
    this.enabled = true,
  });

  final ValueChanged<String> onChanged;
  final String initialValue;
  final bool enabled;

  @override
  State<NearbyItemsInput> createState() => _NearbyItemsInputState();
}

class _NearbyItemsInputState extends State<NearbyItemsInput> {
  final _controller = TextEditingController();
  final Set<String> _selectedItems = {};

  static const _suggestions = [
    ('🕯️', 'candle'),
    ('🪴', 'plant'),
    ('💧', 'water'),
    ('📱', 'phone'),
    ('📖', 'book'),
    ('🪟', 'window'),
    ('🎧', 'headphones'),
    ('☕', 'tea'),
    ('🛋️', 'blanket'),
    ('✏️', 'notebook'),
  ];

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialValue;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleSuggestion(String item) {
    if (!widget.enabled) return;
    setState(() {
      if (_selectedItems.contains(item)) {
        _selectedItems.remove(item);
      } else {
        _selectedItems.add(item);
      }
      _rebuildText();
    });
  }

  void _rebuildText() {
    // Merge typed text with chip-selected items
    final typed = _controller.text
        .split(RegExp(r'[,\n]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && !_suggestions.any((sg) => sg.$2 == s))
        .toList();

    final all = [..._selectedItems, ...typed];
    _controller.text = all.join(', ');
    _controller.selection =
        TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
    widget.onChanged(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "What's around you right now?",
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
        ),
        const SizedBox(height: 10),
        // Quick-add bubbles
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _suggestions.map((sg) {
            final isSelected = _selectedItems.contains(sg.$2);
            return _BubbleChip(
              emoji: sg.$1,
              label: sg.$2,
              isSelected: isSelected,
              isDark: isDark,
              cs: cs,
              enabled: widget.enabled,
              onTap: () => _toggleSuggestion(sg.$2),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        // Free text field
        TextField(
          controller: _controller,
          enabled: widget.enabled,
          minLines: 1,
          maxLines: 2,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: 'or type anything else...',
            prefixIcon: Icon(Icons.search_rounded, color: cs.secondary),
          ),
          onChanged: (v) => widget.onChanged(v),
        ),
      ],
    );
  }
}

class _BubbleChip extends StatefulWidget {
  const _BubbleChip({
    required this.emoji,
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.cs,
    required this.enabled,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool isSelected;
  final bool isDark;
  final ColorScheme cs;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_BubbleChip> createState() => _BubbleChipState();
}

class _BubbleChipState extends State<_BubbleChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _bounce;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _bounce = Tween<double>(begin: 1.0, end: 0.88)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.enabled ? (_) => _ctrl.forward() : null,
      onTapUp: widget.enabled
          ? (_) {
              _ctrl.reverse();
              widget.onTap();
            }
          : null,
      onTapCancel: widget.enabled ? () => _ctrl.reverse() : null,
      child: ScaleTransition(
        scale: _bounce,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? widget.cs.secondary.withOpacity(widget.isDark ? 0.3 : 0.12)
                : (widget.isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.black.withOpacity(0.04)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isSelected
                  ? widget.cs.secondary.withOpacity(0.7)
                  : (widget.isDark
                      ? Colors.white.withOpacity(0.12)
                      : Colors.black.withOpacity(0.1)),
              width: widget.isSelected ? 2 : 1.5,
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: widget.cs.secondary.withOpacity(0.2),
                      blurRadius: 8,
                      spreadRadius: -2,
                    )
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 5),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: widget.isSelected
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: widget.isSelected
                      ? widget.cs.secondary
                      : (widget.isDark
                          ? Colors.white.withOpacity(0.75)
                          : Colors.black.withOpacity(0.65)),
                ),
              ),
              if (widget.isSelected) ...[
                const SizedBox(width: 4),
                Icon(Icons.check_rounded,
                    size: 14, color: widget.cs.secondary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}