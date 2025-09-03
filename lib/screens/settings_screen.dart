// PATH: lib/screens/settings_screen.dart
import 'package:flutter/material.dart';

// App-wide toggles (read/write from anywhere by importing this file)
final ValueNotifier<bool> ghostMode = ValueNotifier(false);
final ValueNotifier<bool> shareWithProvider = ValueNotifier(false);

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: ghostMode,
          builder: (_, v, __) => SwitchListTile(
            title: const Text('Ghost mode (hide from friends)'),
            value: v,
            onChanged: (nv) => ghostMode.value = nv,
          ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: shareWithProvider,
          builder: (_, v, __) => SwitchListTile(
            title: const Text('Share with my provider'),
            value: v,
            onChanged: (nv) => shareWithProvider.value = nv,
          ),
        ),
      ],
    );
  }
}
