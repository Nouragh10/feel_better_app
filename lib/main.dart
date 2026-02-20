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
import 'screens/auth_screen.dart';

import 'widgets/action_timer.dart';
import 'widgets/daily_exercise_card.dart';
import 'widgets/crisis_alert_dialog.dart';
import 'widgets/mood_chip_selector.dart';
import 'widgets/nearby_items_input.dart';
import 'widgets/confetti_overlay.dart';

// ------------------ Brand Palette ------------------
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
      title: 'Nearby',
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
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData && snapshot.data != null) {
            return const MainShell();
          }
          return AuthScreen();
        },
      ),
    );
  }
}

// ============================================================================
// MAIN SHELL WITH BOTTOM NAVIGATION
// ============================================================================

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialIndex = 0});
  final int initialIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  static const _screens = [
    SuggestionScreen(),
    FriendsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark
              ? kBgDarkMid.withOpacity(0.95)
              : kGlassLight.withOpacity(0.95),
          border: Border(
            top: BorderSide(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.06),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.3)
                  : cs.primary.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.spa_rounded,
                  activeIcon: Icons.spa_rounded,
                  label: 'Nearby',
                  index: 0,
                  currentIndex: _currentIndex,
                  onTap: (i) => setState(() => _currentIndex = i),
                  cs: cs,
                ),
                _NavItem(
                  icon: Icons.people_outline_rounded,
                  activeIcon: Icons.people_rounded,
                  label: 'Friends',
                  index: 1,
                  currentIndex: _currentIndex,
                  onTap: (i) => setState(() => _currentIndex = i),
                  cs: cs,
                ),
                _NavItem(
                  icon: Icons.account_circle_outlined,
                  activeIcon: Icons.account_circle_rounded,
                  label: 'Profile',
                  index: 2,
                  currentIndex: _currentIndex,
                  onTap: (i) => setState(() => _currentIndex = i),
                  cs: cs,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
    required this.cs,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final isActive = currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? cs.primary.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isActive ? activeIcon : icon,
                  key: ValueKey(isActive),
                  color: isActive ? cs.primary : cs.onSurface.withOpacity(0.45),
                  size: 26,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? cs.primary : cs.onSurface.withOpacity(0.45),
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SUGGESTION SCREEN
// ============================================================================

class SuggestionScreen extends StatefulWidget {
  const SuggestionScreen({super.key});

  @override
  State<SuggestionScreen> createState() => _SuggestionScreenState();
}

class _SuggestionScreenState extends State<SuggestionScreen>
    with SingleTickerProviderStateMixin {
  final _fs = FirestoreService();

  // State
  String _mood = '';
  String _items = '';
  bool _loading = false;
  bool _saving = false;
  String? _suggestion;
  String? _extractedLink;
  bool _shareWithFriends = true;
  bool _shareWithProvider = false;

  // Content type selection (now visible upfront)
  String? _selectedContentType;

  // Variation index
  int _suggestionIndex = 0;

  // Animation
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // ---- Helpers ----

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

  String _cleanSuggestionText(String suggestion) {
    var cleaned = suggestion;
    cleaned = cleaned.replaceAll(
        RegExp(r'[Ss]earch:\s*https?://[^\s]+', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(
        RegExp(r'https?://[^\s]+', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s*-\s*$'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    return cleaned.trim();
  }

  // ---- Core Logic ----

  Future<void> _getSuggestion() async {
    if (_mood.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('How are you feeling right now?'),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final items = _parseItems(_items);

    // Crisis check
    final crisisCheck = OpenAIService.detectCrisis(mood: _mood, items: items);
    if (crisisCheck.isCrisis) {
      await CrisisAlertDialog.show(
        context,
        crisisCheck.safetyMessage ?? 'Please reach out for help',
        crisisCheck.hotlines,
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
      final result = await OpenAIService.suggestWithVariation(
        apiKey: apiKey.isEmpty ? null : apiKey,
        mood: _mood,
        items: items,
        userPreferences: prefs,
        contentType: _selectedContentType,
        variationIndex: _suggestionIndex,
      );

      if (!mounted) return;

      setState(() {
        _suggestion = _cleanSuggestionText(result.suggestion);
        _extractedLink = result.linkUrl;
        _suggestionIndex++;
      });
      _fadeController.forward(from: 0);
    } on TimeoutException {
      if (!mounted) return;
      setState(() => _suggestion = 'Network timeout — try again in a moment.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _suggestion = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _getNewSuggestion() {
    setState(() {
      _suggestion = null;
      _extractedLink = null;
    });
    _getSuggestion();
  }

  void _startOver() {
    setState(() {
      _mood = '';
      _items = '';
      _suggestion = null;
      _extractedLink = null;
      _selectedContentType = null;
      _suggestionIndex = 0;
    });
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _saveEntry() async {
    if (_suggestion == null) return;
    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'local';
      final entryId = await _fs.addEntry(
        uid: uid,
        mood: _mood,
        nearby: _items,
        suggestion: _suggestion!.trim(),
        shareWithFriends: _shareWithFriends,
        shareWithProviders: _shareWithProvider,
        publicSummary: 'felt $_mood and was recommended: ${_suggestion!.trim()}',
        createdAtLocal: DateTime.now(),
      );

      if (_shareWithFriends && !ghostMode.value) {
        await _fs.mirrorPublicEntry(
          entryId: entryId,
          authorId: uid,
          publicSummary:
              'felt $_mood and was recommended: ${_suggestion!.trim()}',
        );
        try {
          final userSnap = await _fs.getUser(uid);
          final userData = userSnap.data();
          final username = userData?['username'] as String? ?? 'Someone';
          await _fs.notifyTrustedPerson(
            fromUid: uid,
            fromUsername: username,
            summary:
                'felt $_mood and was recommended: ${_suggestion!.trim()}',
          );
        } catch (_) {}
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_shareWithFriends && !ghostMode.value
              ? 'Saved and shared with friends ✨'
              : 'Moment saved ✨'),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save: $e'),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      // Trigger confetti on action complete
      ConfettiOverlay.show(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔥 Daily streak updated!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {}
  }

  // ============================================================================
  // BUILD
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient:
                    LinearGradient(colors: [cs.primary, cs.secondary]),
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  const Icon(Icons.spa_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('Nearby'),
          ],
        ),
        actions: [
          // Ghost mode moved to a subtle icon
          ValueListenableBuilder<bool>(
            valueListenable: ghostMode,
            builder: (_, isOn, __) => IconButton(
              tooltip: isOn ? 'Ghost mode ON' : 'Ghost mode OFF',
              icon: Icon(
                isOn
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: isOn
                    ? cs.onSurface.withOpacity(0.4)
                    : cs.onSurface.withOpacity(0.7),
                size: 22,
              ),
              onPressed: () => ghostMode.value = !ghostMode.value,
            ),
          ),
          const SizedBox(width: 4),
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
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const DailyExerciseCard(),
                    const SizedBox(height: 28),

                    // ---- Mood chips ----
                    _buildGlassCard(
                      isDark: isDark,
                      cs: cs,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: MoodChipSelector(
                          initialMood: _mood,
                          onMoodSelected: (v) => setState(() => _mood = v),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ---- Nearby items ----
                    _buildGlassCard(
                      isDark: isDark,
                      cs: cs,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: NearbyItemsInput(
                          initialValue: _items,
                          enabled: _suggestion == null,
                          onChanged: (v) => setState(() => _items = v),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ---- Content type picker (always visible) ----
                    if (_suggestion == null)
                      _buildGlassCard(
                        isDark: isDark,
                        cs: cs,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: _buildContentTypePicker(cs: cs, isDark: isDark),
                        ),
                      ),

                    const SizedBox(height: 28),

                    // ---- Get suggestion button ----
                    if (_suggestion == null)
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
                                    Text('Find my action'),
                                  ],
                                ),
                        ),
                      ),

                    // ---- Result ----
                    if (_suggestion != null)
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          children: [
                            _buildResultCard(isDark: isDark, cs: cs),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 54,
                                    child: OutlinedButton.icon(
                                      onPressed: _startOver,
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                            color: cs.outline.withOpacity(0.5)),
                                        foregroundColor: cs.onSurface,
                                      ),
                                      icon: const Icon(Icons.refresh_rounded,
                                          size: 20),
                                      label: const Text('Start over'),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SizedBox(
                                    height: 54,
                                    child: FilledButton.icon(
                                      onPressed: _getNewSuggestion,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: cs.primary,
                                        foregroundColor: cs.onPrimary,
                                      ),
                                      icon: const Icon(Icons.auto_awesome_rounded,
                                          size: 20),
                                      label: const Text('Try another'),
                                    ),
                                  ),
                                ),
                              ],
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
      ),
    );
  }

  // ============================================================================
  // UI HELPERS
  // ============================================================================

  Widget _buildContentTypePicker(
      {required ColorScheme cs, required bool isDark}) {
    const types = [
      ('song', '🎵', 'Song'),
      ('podcast', '🎙️', 'Podcast'),
      ('video', '📹', 'Video'),
      ('exercise', '🧘', 'Exercise'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'I want to...',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
        ),
        const SizedBox(height: 12),
        Row(
          children: types.map((t) {
            final isSelected = _selectedContentType == t.$1;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() {
                    _selectedContentType = isSelected ? null : t.$1;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? cs.primary.withOpacity(isDark ? 0.3 : 0.12)
                          : (isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.black.withOpacity(0.03)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? cs.primary.withOpacity(0.7)
                            : (isDark
                                ? Colors.white.withOpacity(0.1)
                                : Colors.black.withOpacity(0.08)),
                        width: isSelected ? 2 : 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(t.$2,
                            style: TextStyle(
                                fontSize: isSelected ? 22 : 20)),
                        const SizedBox(height: 4),
                        Text(
                          t.$3,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? cs.primary
                                : cs.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (_selectedContentType == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Leave blank to let us decide ✨',
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withOpacity(0.45),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGlassCard(
      {required bool isDark,
      required ColorScheme cs,
      required Widget child}) {
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
              ? [kGlassDark.withOpacity(0.7), kGlassDark.withOpacity(0.5)]
              : [kGlassLight.withOpacity(0.9), kGlassLight.withOpacity(0.7)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: cs.primary.withOpacity(0.3), width: 2),
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
                  gradient:
                      LinearGradient(colors: [cs.primary, cs.secondary]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Here\'s what to do',
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
                  height: 1.6,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Open link',
                    style: TextStyle(fontSize: 14)),
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
                  onChanged: (v) =>
                      setState(() => _shareWithFriends = v ?? true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCompactCheckOption(
                  cs: cs,
                  value: _shareWithProvider,
                  label: 'Provider',
                  icon: Icons.medical_services_rounded,
                  onChanged: (v) =>
                      setState(() => _shareWithProvider = v ?? false),
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
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.bookmark_rounded, size: 20),
              label: Text(_saving ? 'Saving...' : 'Save this moment'),
            ),
          ),
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
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: value
              ? cs.primaryContainer.withOpacity(0.5)
              : cs.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: value
                ? cs.primary.withOpacity(0.5)
                : cs.outline.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 18,
                color: value ? cs.primary : cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: value ? cs.primary : cs.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              value ? Icons.check_circle : Icons.circle_outlined,
              size: 16,
              color: value
                  ? cs.primary
                  : cs.onSurfaceVariant.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }
}