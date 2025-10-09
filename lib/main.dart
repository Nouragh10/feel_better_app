// PATH: lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';

import 'firebase_options.dart';
import 'services/openai_service.dart';
import 'services/firestore_service.dart';

import 'screens/friends_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart' show ghostMode;

import 'widgets/ghost_mode_button.dart';
import 'widgets/action_timer.dart';

// ------------------ Elevated Brand Palette ------------------
const kPrimaryCyan = Color(0xFF06B6D4);
const kSecondaryPurple = Color(0xFF8B5CF6);
const kAccentCoral = Color(0xFFFF6B9D);

const kBgLightTop = Color(0xFFF0F9FF);
const kBgLightMid = Color(0xFFFAFAFF);
const kBgLightEnd = Color(0xFFFFFFFF);

const kBgDarkTop = Color(0xFF0B1120);
const kBgDarkMid = Color(0xFF0F172A);
const kBgDarkEnd = Color(0xFF1E293B);

const kGlassLight = Color(0xFFFEFEFE);
const kGlassDark = Color(0xFF1A2332);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
    final light = ColorScheme.fromSeed(
      seedColor: kPrimaryCyan,
      brightness: Brightness.light,
      secondary: kSecondaryPurple,
      tertiary: kAccentCoral,
    );
    final dark = ColorScheme.fromSeed(
      seedColor: kPrimaryCyan,
      brightness: Brightness.dark,
      secondary: kSecondaryPurple,
      tertiary: kAccentCoral,
    );

    return MaterialApp(
      title: 'Feel Better',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: light,
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
          displayMedium: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
          titleLarge: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3),
          titleMedium: TextStyle(fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(fontWeight: FontWeight.w400, height: 1.5),
          bodyMedium: TextStyle(fontWeight: FontWeight.w400, height: 1.5),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: light.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: kGlassLight.withOpacity(0.7),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: light.surface.withOpacity(0.8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: light.primary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          hintStyle: TextStyle(color: light.onSurface.withOpacity(0.4)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 0,
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.3),
          ),
        ),
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: light.surfaceVariant,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: dark,
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
          displayMedium: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
          titleLarge: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3),
          titleMedium: TextStyle(fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(fontWeight: FontWeight.w400, height: 1.5),
          bodyMedium: TextStyle(fontWeight: FontWeight.w400, height: 1.5),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: dark.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: kGlassDark.withOpacity(0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: dark.surface.withOpacity(0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: dark.primary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          hintStyle: TextStyle(color: dark.onSurface.withOpacity(0.3)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 0,
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.3),
          ),
        ),
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: dark.surfaceVariant,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
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

class _SuggestionScreenState extends State<SuggestionScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _moodController = TextEditingController();
  final TextEditingController _itemsController = TextEditingController();
  final _fs = FirestoreService();

  bool _loading = false;
  bool _saving = false;
  String? _suggestion;
  String? _extractedLink;
  bool _shareWithFriends = true;
  bool _shareWithProvider = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _moodController.dispose();
    _itemsController.dispose();
    _fadeController.dispose();
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

    final sp = await SharedPreferences.getInstance();
    var uid = sp.getString('local_uid');
    if (uid == null) {
      uid = const Uuid().v4();
      await sp.setString('local_uid', uid);
    }
    return uid;
  }

  String? _extractLinkFromSuggestion(String suggestion) {
    final urlRegex = RegExp(
      r'https?://[^\s\)]+',
      caseSensitive: false,
    );
    final match = urlRegex.firstMatch(suggestion);
    return match?.group(0);
  }

  String? _generateLinkForSuggestion(String suggestion, String mood, List<String> items) {
    final s = suggestion.toLowerCase();
    final m = mood.toLowerCase();
    
    if (s.contains('play') || s.contains('listen') || s.contains('song')) {
      final songMatch = RegExp(r'"([^"]+)"').firstMatch(suggestion);
      if (songMatch != null) {
        final songName = songMatch.group(1)!;
        return 'https://www.google.com/search?q=${Uri.encodeComponent(songName)}';
      }
      
      final yourMatch = RegExp(r'your\s+(?:go-to\s+)?(\w+)').firstMatch(s);
      if (yourMatch != null) {
        if (m.contains('sad') || m.contains('low') || m.contains('down')) {
          return 'https://www.google.com/search?q=${Uri.encodeComponent('uplifting happy song')}';
        } else if (m.contains('anx') || m.contains('tense') || m.contains('panic')) {
          return 'https://www.google.com/search?q=${Uri.encodeComponent('calming relaxing song')}';
        }
      }
      
      return 'https://www.google.com/search?q=${Uri.encodeComponent('feel good music')}';
    }
    
    if (s.contains('watch')) {
      return 'https://www.youtube.com/results?search_query=${Uri.encodeComponent('calming video 2 minutes')}';
    }
    
    if (s.contains('recipe') || s.contains('snack')) {
      return 'https://www.google.com/search?q=${Uri.encodeComponent('quick 5 minute snack recipe')}';
    }
    
    return null;
  }

  String _cleanSuggestionText(String suggestion) {
    var cleaned = suggestion;
    cleaned = cleaned.replaceAll(
      RegExp(r'[Ss]earch:\s*https?://[^\s]+', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'https?://[^\s]+', caseSensitive: false),
      '',
    );
    final trailingDash = RegExp(r'\s*-\s*$');
    cleaned = cleaned.replaceAll(trailingDash, '');
    final multiSpace = RegExp(r'\s+');
    cleaned = cleaned.replaceAll(multiSpace, ' ');
    cleaned = cleaned.trim();
    return cleaned;
  }

  Future<void> _getSuggestion() async {
    final mood = _moodController.text.trim();
    final items = _parseItems(_itemsController.text);

    if (mood.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Tell us how you are feeling'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
      _extractedLink = null;
    });
    
    try {
      Map<String, String>? prefs;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        try {
          final snap = await _fs.getUser(uid);
          final data = snap.data();
          prefs = (data?['personalPreferences'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, value.toString()),
          );
        } catch (_) {}
      }

      final apiKey = const String.fromEnvironment('OPENAI_API_KEY');
      final result = await OpenAIService.suggest(
        apiKey: apiKey.isEmpty ? null : apiKey,
        mood: mood,
        items: items,
        userPreferences: prefs,
      );

      if (!mounted) return;
      
      var link = _extractLinkFromSuggestion(result);
      
      if (link == null) {
        link = _generateLinkForSuggestion(result, mood, items);
      }
      
      final cleanedSuggestion = _cleanSuggestionText(result);
      
      setState(() {
        _suggestion = cleanedSuggestion;
        _extractedLink = link;
      });
      _fadeController.forward(from: 0);
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

  Future<void> _openLink() async {
    if (_extractedLink == null) return;
    
    final uri = Uri.parse(_extractedLink!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not open link'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
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

      if (_shareWithFriends && !ghostMode.value) {
        await _fs.mirrorPublicEntry(
          entryId: entryId,
          authorId: uid,
          publicSummary: 'felt $mood and was recommended: $suggestion',
        );
        
        try {
          final userSnap = await _fs.getUser(uid);
          final userData = userSnap.data();
          final username = userData?['username'] as String? ?? 'Someone';
          await _fs.notifyTrustedPerson(
            fromUid: uid,
            fromUsername: username,
            summary: 'felt $mood and was recommended: $suggestion',
          );
        } catch (_) {}
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_shareWithFriends && !ghostMode.value
              ? 'Saved and shared with friends'
              : 'Saved'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save: $e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _onActionTimerComplete() async {
    final uid = await _getUid();
    try {
      await _fs.updateUserDailyStreakOnActionComplete(uid: uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Daily streak updated!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update streak: $e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Feel Better'),
        actions: [
          const GhostModeButton(compact: true),
          IconButton(
            tooltip: 'Friends',
            icon: const Icon(Icons.people_rounded, size: 24),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FriendsScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Profile',
            icon: const Icon(Icons.account_circle_rounded, size: 24),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [kBgDarkTop, kBgDarkMid, kBgDarkEnd]
                : [kBgLightTop, kBgLightMid, kBgLightEnd],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    
                    Text(
                      'How are you feeling?',
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Let us find a gentle action together',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: cs.onSurface.withOpacity(0.6),
                      ),
                    ),
                    
                    const SizedBox(height: 32),

                    _buildGlassCard(
                      isDark: isDark,
                      cs: cs,
                      child: TextField(
                        controller: _moodController,
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          labelText: 'Your mood',
                          hintText: 'anxious, low, overwhelmed...',
                          prefixIcon: Icon(Icons.mood_rounded, color: cs.primary),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),

                    _buildGlassCard(
                      isDark: isDark,
                      cs: cs,
                      child: TextField(
                        controller: _itemsController,
                        minLines: 2,
                        maxLines: 3,
                        style: const TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          labelText: 'What is nearby?',
                          hintText: 'candle, water, window, plant...',
                          prefixIcon: Icon(Icons.spa_rounded, color: cs.secondary),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: FilledButton(
                        onPressed: _loading ? null : _getSuggestion,
                        style: FilledButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.auto_awesome_rounded, size: 22),
                                  SizedBox(width: 12),
                                  Text('Get your suggestion'),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    if (_suggestion != null)
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: _buildResultCard(isDark: isDark, cs: cs),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassCard({
    required bool isDark,
    required ColorScheme cs,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark 
            ? kGlassDark.withOpacity(0.4) 
            : kGlassLight.withOpacity(0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark 
              ? Colors.white.withOpacity(0.1) 
              : Colors.white.withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 24,
            spreadRadius: -8,
            offset: const Offset(0, 8),
            color: isDark 
                ? Colors.black.withOpacity(0.3)
                : cs.primary.withOpacity(0.08),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildResultCard({required bool isDark, required ColorScheme cs}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  kGlassDark.withOpacity(0.7),
                  kGlassDark.withOpacity(0.5),
                ]
              : [
                  kGlassLight.withOpacity(0.9),
                  kGlassLight.withOpacity(0.7),
                ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: cs.primary.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 32,
            spreadRadius: -4,
            offset: const Offset(0, 12),
            color: cs.primary.withOpacity(0.15),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cs.primary, cs.secondary],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.lightbulb_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your suggestion',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Text(
            _suggestion!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 15,
              height: 1.5,
              color: cs.onSurface.withOpacity(0.9),
            ),
          ),

          if (_extractedLink != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton.icon(
                onPressed: _openLink,
                style: FilledButton.styleFrom(
                  backgroundColor: cs.tertiary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Open link', style: TextStyle(fontSize: 14)),
              ),
            ),
          ],

          const SizedBox(height: 20),
          Divider(color: cs.outline.withOpacity(0.2), height: 1),
          const SizedBox(height: 16),

          ActionTimer(
            initialSeconds: 60,
            options: const [60, 120, 300],
            onComplete: _onActionTimerComplete,
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _buildCompactCheckOption(
                  cs: cs,
                  value: _shareWithFriends,
                  label: 'Friends',
                  icon: Icons.people_rounded,
                  onChanged: (v) => setState(() => _shareWithFriends = v ?? true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCompactCheckOption(
                  cs: cs,
                  value: _shareWithProvider,
                  label: 'Provider',
                  icon: Icons.medical_services_rounded,
                  onChanged: (v) => setState(() => _shareWithProvider = v ?? false),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _saving ? null : _saveEntry,
              style: FilledButton.styleFrom(
                backgroundColor: cs.secondary,
                foregroundColor: cs.onSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.bookmark_rounded, size: 20),
              label: Text(
                _saving ? 'Saving...' : 'Save this moment',
                style: const TextStyle(fontSize: 15),
              ),
            ),
          ),

          if (ghostMode.value) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.visibility_off_rounded, size: 13, color: cs.outline),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Ghost mode on — not shared with friends',
                    style: TextStyle(fontSize: 11, color: cs.outline),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactCheckOption({
    required ColorScheme cs,
    required bool value,
    required String label,
    required IconData icon,
    required ValueChanged<bool?> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: value ? cs.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value ? cs.primary : cs.outline.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: value ? cs.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: value ? cs.primary : cs.outline.withOpacity(0.5),
                  width: 2,
                ),
              ),
              child: value
                  ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 8),
            Icon(icon, size: 16, color: cs.onSurface.withOpacity(0.7)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}