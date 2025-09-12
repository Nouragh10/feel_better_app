// PATH: lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'firebase_options.dart';
import 'services/openai_service.dart';
import 'services/firestore_service.dart';

import 'screens/friends_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart' show ghostMode; // global ValueNotifier

import 'widgets/ghost_mode_button.dart';
import 'widgets/action_timer.dart';

// ------------------ Brand palette & theming helpers ------------------

// Pick one seed color for both light/dark color schemes:
const kSeedCalmTeal = Color(0xFF0FA3B1); // calming teal (recommended)
const kSeedWarmCoral = Color(0xFFFF6F61); // warm coral
const kSeedIndigo    = Color(0xFF574AE2); // deep indigo

const kBrandSeed = kSeedCalmTeal; // <- swap this to try the other palettes

// Soft gradient background (light)
const kBgLightTop = Color(0xFFEFF9F6);
const kBgLightMid = Color(0xFFF7FBFA);
const kBgLightEnd = Color(0xFFFFFFFF);

// Soft gradient background (dark)
const kBgDarkTop = Color(0xFF0D1513);
const kBgDarkMid = Color(0xFF0F1B19);
const kBgDarkEnd = Color(0xFF0B0F0E);

// ---------------------------------------------------------------------

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Try anonymous auth (fine if it fails; we have a local fallback)
  try {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  } catch (_) {}

  runApp(const FeelBetterApp());
}

class FeelBetterApp extends StatelessWidget {
  const FeelBetterApp({super.key});

  @override
  Widget build(BuildContext context) {
    final light = ColorScheme.fromSeed(seedColor: kBrandSeed, brightness: Brightness.light);
    final dark  = ColorScheme.fromSeed(seedColor: kBrandSeed, brightness: Brightness.dark);

    return MaterialApp(
      title: 'Feel Better',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system, // follow device preference
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: light,
        textTheme: const TextTheme().apply(
          bodyColor: light.onSurface,
          displayColor: light.onSurface,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: light.surface,
          surfaceTintColor: light.surfaceTint,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: const TextStyle(
            fontSize: 20, fontWeight: FontWeight.w700,
          ).copyWith(color: light.onSurface),
        ),
        // FIX: CardThemeData (not CardTheme)
        cardTheme: CardThemeData(
          elevation: 0,
          color: light.surface,
          surfaceTintColor: light.surfaceTint,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: light.surfaceVariant.withOpacity(0.6),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: light.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: light.primary, width: 1.6),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: light.outlineVariant),
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
        checkboxTheme: CheckboxThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          fillColor: WidgetStatePropertyAll(light.primary),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: light.inverseSurface,
          contentTextStyle: TextStyle(color: light.onInverseSurface),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: dark,
        appBarTheme: AppBarTheme(
          backgroundColor: dark.surface,
          surfaceTintColor: dark.surfaceTint,
          elevation: 0,
          titleTextStyle: const TextStyle(
            fontSize: 20, fontWeight: FontWeight.w700,
          ).copyWith(color: dark.onSurface),
        ),
        // FIX: CardThemeData (not CardTheme)
        cardTheme: CardThemeData(
          elevation: 0,
          color: dark.surface,
          surfaceTintColor: dark.surfaceTint,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: dark.surfaceVariant.withOpacity(0.5),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: dark.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: dark.primary, width: 1.6),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: dark.outlineVariant),
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
        checkboxTheme: CheckboxThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          fillColor: WidgetStatePropertyAll(dark.primary),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: dark.inverseSurface,
          contentTextStyle: TextStyle(color: dark.onInverseSurface),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      home: const SuggestionScreen(),
    );
  }
}

class SuggestionScreen extends StatefulWidget {
  const SuggestionScreen({super.key});

  @override
  State<SuggestionScreen> createState() => _SuggestionScreenState();
}

class _SuggestionScreenState extends State<SuggestionScreen> {
  final TextEditingController _moodController = TextEditingController();
  final TextEditingController _itemsController = TextEditingController();

  final _fs = FirestoreService();

  bool _loading = false;     // getting AI suggestion
  bool _saving = false;      // saving to Firestore
  String? _suggestion;

  // Per-entry share toggles
  bool _shareWithFriends = true;
  bool _shareWithProvider = false;

  @override
  void dispose() {
    _moodController.dispose();
    _itemsController.dispose();
    super.dispose();
  }

  List<String> _parseItems(String raw) {
    return raw
        .split(RegExp(r'[,\n]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<String> _getUid() async {
    final cur = FirebaseAuth.instance.currentUser;
    if (cur != null) return cur.uid;

    // Dev fallback: persistent local ID so saving & sharing works on desktop/web
    final sp = await SharedPreferences.getInstance();
    var uid = sp.getString('local_uid');
    if (uid == null) {
      uid = const Uuid().v4();
      await sp.setString('local_uid', uid);
    }
    return uid;
  }

  Future<void> _getSuggestion() async {
    final mood = _moodController.text.trim();
    final items = _parseItems(_itemsController.text);

    if (mood.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe your mood.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      // Read the key from a compile-time env define (may be empty in web)
      final apiKey = const String.fromEnvironment('OPENAI_API_KEY');

      final result = await OpenAIService.suggest(
        apiKey: apiKey.isEmpty ? null : apiKey,
        mood: mood,
        items: items,
      );

      if (!mounted) return;
      setState(() => _suggestion = result);
    } on TimeoutException {
      if (!mounted) return;
      setState(() => _suggestion = 'Network timeout—try again in a moment.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _suggestion = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveEntry() async {
    if (_suggestion == null) return;

    final mood = _moodController.text.trim();
    final nearby = _itemsController.text.trim();
    final suggestion = _suggestion!.trim();

    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'local';

      // Save primary entry
      final entryId = await _fs.addEntry(
        uid: uid,
        mood: mood,
        nearby: nearby,
        suggestion: suggestion,
        shareWithFriends: _shareWithFriends,
        shareWithProviders: _shareWithProvider,
        publicSummary: 'felt $mood and was recommended: $suggestion',
        createdAtLocal: DateTime.now(),
      );

      // Mirror to public feed for friends if allowed and not in Ghost mode
      if (_shareWithFriends && !ghostMode.value) {
        await _fs.mirrorPublicEntry(
          entryId: entryId,
          authorId: uid,
          publicSummary: 'felt $mood and was recommended: $suggestion',
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_shareWithFriends && !ghostMode.value
              ? 'Saved and shared with friends.'
              : 'Saved.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn’t save: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // When the action timer finishes, bump the user's personal daily streak (once/day).
  Future<void> _onActionTimerComplete() async {
    final uid = await _getUid();
    try {
      await _fs.updateUserDailyStreakOnActionComplete(uid: uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nice job — daily streak updated!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn’t update streak: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // No backgroundColor here; the gradient below handles it.
      appBar: AppBar(
        title: const Text('Feel Better'),
        actions: [
          const GhostModeButton(compact: true), // toggle
          IconButton(
            tooltip: 'Friends & Pings',
            icon: const Icon(Icons.group_add_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FriendsScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'My Profile',
            icon: const Icon(Icons.person_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: isDark
                ? const [kBgDarkTop, kBgDarkMid, kBgDarkEnd]
                : const [kBgLightTop, kBgLightMid, kBgLightEnd],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mood
                  TextField(
                    controller: _moodController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Your mood',
                      hintText: 'anxious, low, tense…',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Nearby items
                  TextField(
                    controller: _itemsController,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Nearby items',
                      hintText:
                          'e.g., candle, water, window, plant (comma-separated)',
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Get suggestion
                  SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: _loading ? null : _getSuggestion,
                      icon: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.lightbulb_rounded),
                      label: Text(_loading ? 'Thinking…' : 'Get suggestion'),
                      style: FilledButton.styleFrom(
                        textStyle: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Result + timer + share controls
                  if (_suggestion != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 18,
                            spreadRadius: -6,
                            offset: const Offset(0, 8),
                            color: Colors.black.withOpacity(0.06),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Suggestion text
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.verified_rounded,
                                  color: cs.primary, size: 30),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _suggestion!,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Timer widget (calls daily streak update on complete)
                          ActionTimer(
                            initialSeconds: 60,
                            options: const [60, 120, 300],
                            onComplete: _onActionTimerComplete,
                          ),

                          const SizedBox(height: 16),

                          // Share controls + Save
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            runSpacing: 12,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: _shareWithFriends,
                                    onChanged: (v) => setState(
                                        () => _shareWithFriends = v ?? true),
                                  ),
                                  const Text('Share with friends'),
                                  const SizedBox(width: 16),
                                  Checkbox(
                                    value: _shareWithProvider,
                                    onChanged: (v) => setState(
                                        () => _shareWithProvider = v ?? false),
                                  ),
                                  const Text('Share with my provider'),
                                ],
                              ),
                              FilledButton.icon(
                                onPressed: _saving ? null : _saveEntry,
                                icon: _saving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Icon(Icons.save_rounded),
                                label: Text(_saving ? 'Saving…' : 'Save'),
                              ),
                            ],
                          ),

                          const SizedBox(height: 4),
                          if (ghostMode.value)
                            const Text(
                              'Ghost mode is ON — nothing will be shared with friends.',
                              style: TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
