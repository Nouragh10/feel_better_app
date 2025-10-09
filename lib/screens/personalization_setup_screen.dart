// PATH: lib/screens/personalization_setup_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';

// Brand colors
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

class PersonalizationSetupScreen extends StatefulWidget {
  const PersonalizationSetupScreen({super.key, this.isFirstTime = true});

  final bool isFirstTime;

  @override
  State<PersonalizationSetupScreen> createState() => _PersonalizationSetupScreenState();
}

class _PersonalizationSetupScreenState extends State<PersonalizationSetupScreen> {
  final _fs = FirestoreService();
  final _pageController = PageController();
  
  int _currentPage = 0;
  bool _saving = false;

  final _controllers = List.generate(7, (_) => TextEditingController());

  final _questions = [
    {
      'icon': Icons.music_note_rounded,
      'title': 'Favorite song when sad',
      'hint': 'e.g., Happy by Pharrell Williams',
      'description': 'What song lifts your mood when you are feeling down?',
      'key': 'favoriteSongSad',
    },
    {
      'icon': Icons.music_note_rounded,
      'title': 'Favorite song when anxious',
      'hint': 'e.g., Weightless by Marconi Union',
      'description': 'What song calms you when you are feeling anxious?',
      'key': 'favoriteSongAnxious',
    },
    {
      'icon': Icons.podcasts_rounded,
      'title': 'Favorite podcast',
      'hint': 'e.g., The Daily',
      'description': 'Which podcast do you enjoy listening to?',
      'key': 'favoritePodcast',
    },
    {
      'icon': Icons.restaurant_rounded,
      'title': 'Comfort food',
      'hint': 'e.g., Mac and cheese, Tea',
      'description': 'What food or drink brings you comfort?',
      'key': 'comfortFood',
    },
    {
      'icon': Icons.self_improvement_rounded,
      'title': 'Go-to activity',
      'hint': 'e.g., Walk outside, Journaling',
      'description': 'What activity helps you feel better?',
      'key': 'goToActivity',
    },
    {
      'icon': Icons.favorite_rounded,
      'title': 'Trusted person',
      'hint': 'e.g., @glee',
      'description': 'Who should be notified when you share moments? Enter their username.',
      'key': 'trustedPerson',
    },
    {
      'icon': Icons.place_rounded,
      'title': 'Safe space',
      'hint': 'e.g., My bedroom, Local park',
      'description': 'Where do you feel most calm and safe?',
      'key': 'safeSpace',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;

    try {
      final snap = await _fs.getUser(u.uid);
      final data = snap.data();
      final prefs = data?['personalPreferences'] as Map<String, dynamic>?;
      
      if (prefs != null) {
        for (int i = 0; i < _questions.length; i++) {
          final key = _questions[i]['key'] as String;
          final value = prefs[key] as String? ?? '';
          
          // Add @ prefix for trusted person if not present
          if (key == 'trustedPerson' && value.isNotEmpty && !value.startsWith('@')) {
            _controllers[i].text = '@$value';
          } else {
            _controllers[i].text = value;
          }
        }
      }
    } catch (_) {}
  }

  Future<bool> _validateTrustedPerson(String username) async {
    if (username.isEmpty) return true;
    
    final cleanUsername = username.startsWith('@') ? username.substring(1) : username;
    
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return false;
      
      final targetUid = await _fs.getUidByUsername(cleanUsername);
      if (targetUid == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('User @$cleanUsername not found'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        return false;
      }
      
      final friendDoc = await FirebaseFirestore.instance
          .collection('friendships')
          .doc(uid)
          .collection('friends')
          .doc(targetUid)
          .get();
      
      if (!friendDoc.exists || friendDoc.data()?['status'] != 'accepted') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('@$cleanUsername is not your friend yet. Add them first!'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        return false;
      }
      
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error validating username: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return false;
    }
  }

  Future<void> _save() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;

    final trustedPersonIndex = _questions.indexWhere((q) => q['key'] == 'trustedPerson');
    if (trustedPersonIndex != -1) {
      final trustedPersonValue = _controllers[trustedPersonIndex].text.trim();
      if (trustedPersonValue.isNotEmpty) {
        final isValid = await _validateTrustedPerson(trustedPersonValue);
        if (!isValid) return;
      }
    }

    setState(() => _saving = true);

    try {
      final prefs = <String, String>{};
      for (int i = 0; i < _questions.length; i++) {
        final key = _questions[i]['key'] as String;
        var value = _controllers[i].text.trim();
        
        if (key == 'trustedPerson' && value.isNotEmpty) {
          value = value.startsWith('@') ? value.substring(1) : value;
        }
        
        if (value.isNotEmpty) {
          prefs[key] = value;
        }
      }

      await _fs.updateUserPreferences(uid: u.uid, preferences: prefs);

      if (!mounted) return;
      
      if (widget.isFirstTime) {
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Preferences saved'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.of(context).pop();
      }
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

  void _nextPage() {
    if (_currentPage < _questions.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _save();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
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
        title: Text(widget.isFirstTime ? 'Personalize Your Experience' : 'Edit Preferences'),
        backgroundColor: Colors.transparent,
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Row(
                      children: List.generate(_questions.length, (i) {
                        return Expanded(
                          child: Container(
                            height: 4,
                            margin: EdgeInsets.only(right: i < _questions.length - 1 ? 8 : 0),
                            decoration: BoxDecoration(
                              gradient: i <= _currentPage
                                  ? LinearGradient(colors: [cs.primary, cs.secondary])
                                  : null,
                              color: i > _currentPage
                                  ? cs.surfaceVariant.withOpacity(0.3)
                                  : null,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Question ${_currentPage + 1} of ${_questions.length}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemCount: _questions.length,
                  itemBuilder: (context, i) {
                    final q = _questions[i];
                    return _buildQuestionPage(
                      cs: cs,
                      isDark: isDark,
                      icon: q['icon'] as IconData,
                      title: q['title'] as String,
                      hint: q['hint'] as String,
                      description: q['description'] as String,
                      controller: _controllers[i],
                      isTrustedPerson: q['key'] == 'trustedPerson',
                    );
                  },
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    if (_currentPage > 0)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _previousPage,
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Back'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    if (_currentPage > 0) const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _nextPage,
                        style: FilledButton.styleFrom(
                          backgroundColor: _currentPage == _questions.length - 1
                              ? cs.secondary
                              : cs.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        icon: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(_currentPage == _questions.length - 1
                                ? Icons.check_rounded
                                : Icons.arrow_forward_rounded),
                        label: Text(_saving
                            ? 'Saving...'
                            : _currentPage == _questions.length - 1
                                ? 'Finish'
                                : 'Next'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionPage({
    required ColorScheme cs,
    required bool isDark,
    required IconData icon,
    required String title,
    required String hint,
    required String description,
    required TextEditingController controller,
    bool isTrustedPerson = false,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [kGlassDark.withOpacity(0.7), kGlassDark.withOpacity(0.5)]
                : [kGlassLight.withOpacity(0.9), kGlassLight.withOpacity(0.7)],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isTrustedPerson 
                ? const Color(0xFFFF6B9D).withOpacity(0.4)
                : cs.primary.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 32,
              spreadRadius: -4,
              offset: const Offset(0, 12),
              color: isTrustedPerson
                  ? const Color(0xFFFF6B9D).withOpacity(0.2)
                  : cs.primary.withOpacity(0.15),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isTrustedPerson
                      ? [const Color(0xFFFF6B9D), const Color(0xFFFFB6C1)]
                      : [cs.primary, cs.secondary],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    blurRadius: 20,
                    spreadRadius: 2,
                    color: isTrustedPerson
                        ? const Color(0xFFFF6B9D).withOpacity(0.3)
                        : cs.primary.withOpacity(0.3),
                  ),
                ],
              ),
              child: Icon(icon, size: 40, color: Colors.white),
            ),

            const SizedBox(height: 24),

            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            Text(
              description,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: cs.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            TextField(
              controller: controller,
              maxLines: 2,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: hint,
                prefixIcon: Icon(icon, color: isTrustedPerson ? const Color(0xFFFF6B9D) : cs.primary),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.03),
              ),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: cs.onSurface.withOpacity(0.5)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isTrustedPerson
                        ? 'They will be notified when you share moments and see a special badge'
                        : 'This helps us give you more personalized suggestions',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withOpacity(0.5),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}