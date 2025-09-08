// PATH: lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'widgets/ghost_mode_button.dart';
import 'widgets/friends_shares_feed.dart';
import 'firebase_options.dart';
import 'services/openai_service.dart';
import 'services/firestore_service.dart';
import 'screens/friends_screen.dart';
import 'screens/settings_screen.dart' show ghostMode; // your existing ValueNotifier
import 'widgets/action_timer.dart';
import 'screens/profile_screen.dart'; // Profile screen with Google sign-in

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
    return MaterialApp(
      title: 'Feel Better',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0B6B57),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
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

  // ---- NEW: when the timer finishes, update the user's personal daily streak
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

    return Scaffold(
      backgroundColor: const Color(0xFFF6FBF9),
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
      body: Center(
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
                      color: Colors.black12.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Suggestion text
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.verified_rounded,
                                color: cs.primary, size: 28),
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
    );
  }
}
