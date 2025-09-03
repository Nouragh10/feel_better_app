// PATH: lib/widgets/ghost_mode_button.dart
import 'package:flutter/material.dart';
import '../screens/settings_screen.dart' show ghostMode;

/// A compact button that toggles Ghost Mode (hides shares from friends).
/// Uses the global `ghostMode` ValueNotifier defined in settings_screen.dart.
class GhostModeButton extends StatelessWidget {
  const GhostModeButton({
    super.key,
    this.compact = true,
    this.showIcon = true,
    this.tooltipWhenOn = 'Ghost mode is ON (hidden from friends)',
    this.tooltipWhenOff = 'Ghost mode is OFF (shares visible to friends)',
  });

  /// If true, uses a smaller button style.
  final bool compact;

  /// If false, hides the leading icon.
  final bool showIcon;

  final String tooltipWhenOn;
  final String tooltipWhenOff;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ValueListenableBuilder<bool>(
      valueListenable: ghostMode,
      builder: (context, isOn, _) {
        final label = isOn ? 'Ghost: ON' : 'Ghost: OFF';
        final tooltip = isOn ? tooltipWhenOn : tooltipWhenOff;

        final Widget child = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showIcon)
              Icon(
                isOn ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                size: compact ? 18 : 20,
              ),
            if (showIcon) const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        );

        final onPressed = () => ghostMode.value = !ghostMode.value;

        // Back-compatible style (no tonalStyleFrom).
        final ButtonStyle style = ButtonStyle(
          padding: MaterialStatePropertyAll(
            EdgeInsets.symmetric(
              horizontal: compact ? 12 : 16,
              vertical: compact ? 8 : 12,
            ),
          ),
          minimumSize: const MaterialStatePropertyAll(Size(0, 0)),
          // Give a subtle background when ON; otherwise use default.
          backgroundColor:
              isOn ? MaterialStatePropertyAll(cs.surfaceVariant) : null,
          // Keep text/icon color readable.
          foregroundColor: MaterialStatePropertyAll(cs.onSurface),
        );

        return Tooltip(
          message: tooltip,
          child: Semantics(
            button: true,
            toggled: isOn,
            label: 'Ghost mode',
            value: isOn ? 'On' : 'Off',
            child: FilledButton.tonal(
              onPressed: onPressed,
              style: style,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
