// PATH: lib/screens/friends_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../widgets/streak_chip.dart';
import '../services/firestore_service.dart';
import '../services/openai_service.dart';
import '../widgets/action_timer.dart';

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

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with SingleTickerProviderStateMixin {
  final _fs = FirestoreService();
  final _db = FirebaseFirestore.instance;

  final _myUsernameCtrl = TextEditingController();
  final _addUsernameCtrl = TextEditingController();
  final _pingNoteCtrl = TextEditingController();

  final Map<String, Map<String, dynamic>?> _userCache = {};

  String? _uid;
  bool _usingLocalUid = false;
  String? _authErrorMsg;
  bool _initializing = true;

  late TabController _tabController;

  static const _apiKey = String.fromEnvironment('OPENAI_API_KEY');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initIdentity();
  }

  @override
  void dispose() {
    _myUsernameCtrl.dispose();
    _addUsernameCtrl.dispose();
    _pingNoteCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }



Future<void> _openChat(String friendUid, String friendName) async {
    if (_uid == null) return;
    
    // Create chat ID (deterministic based on both user IDs)
    final chatId = _pairId(_uid!, friendUid);
    
    // Ensure chat document exists
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
    final chatSnap = await chatRef.get();
    
    if (!chatSnap.exists) {
      await chatRef.set({
        'chatId': chatId,
        'participants': [_uid!, friendUid]..sort(),
        'streak': 0,
        'longestStreak': 0,
        'lastActivityDate': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    
    if (!mounted) return;
    
    // Navigate to chat screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          friendId: friendUid,
          friendName: friendName,
          chatId: chatId,
        ),
      ),
    );
  }


// UPDATE YOUR _buildFriendCard method to include a chat button:


Widget _buildFriendCard({
  required ColorScheme cs,
  required bool isDark,
  required String name,
  required String username,
  required String friendUid,
  required String status,
}) {
  return FutureBuilder<bool>(
    future: _isTrustedPerson(friendUid),
    builder: (context, trustedSnap) {
      final isTrusted = trustedSnap.data ?? false;
      
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? kGlassDark.withOpacity(0.4) : kGlassLight.withOpacity(0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isTrusted 
                ? const Color(0xFFFF6B9D).withOpacity(0.5)
                : (isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.5)),
            width: isTrusted ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: cs.primaryContainer,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ),
                if (isTrusted)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: TrustedPersonBadge(),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isTrusted) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF6B9D), Color(0xFFFFB6C1)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Trusted',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@$username • $status',
                    style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.6)),
                  ),
                ],
              ),
            ),
            // ADD CHAT BUTTON HERE
            if (status == 'accepted') ...[
              IconButton(
                tooltip: 'Open chat',
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                onPressed: () => _openChat(friendUid, name),
                color: cs.primary,
              ),
            ],
            _buildFriendActions(cs, friendUid, status),
          ],
        ),
      );
    },
  );
}



  Future<void> _initIdentity() async {
    String? uid;
    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) {
        await auth.signInAnonymously();
      }
      uid = FirebaseAuth.instance.currentUser?.uid;
    } on FirebaseAuthException catch (e) {
      _authErrorMsg = '(${e.code}) ${e.message ?? ''}';
    } catch (e) {
      _authErrorMsg = e.toString();
    }

    if (uid == null) {
      try {
        final sp = await SharedPreferences.getInstance();
        uid = sp.getString('local_uid');
        if (uid == null) {
          uid = const Uuid().v4();
          await sp.setString('local_uid', uid);
        }
        _usingLocalUid = true;
      } catch (_) {
        uid = const Uuid().v4();
        _usingLocalUid = true;
      }
    }

    _uid = uid;

    if (_uid != null) {
      try {
        final snap = await _fs.getUser(_uid!);
        final data = snap.data();
        if (data != null) {
          _myUsernameCtrl.text = data['username'] ?? '';
        }
      } catch (_) {}
    }

    if (mounted) setState(() => _initializing = false);
  }

  Future<Map<String, dynamic>?> _getUser(String uid) async {
    if (_userCache.containsKey(uid)) return _userCache[uid];
    final snap = await _fs.getUser(uid);
    final data = snap.data();
    _userCache[uid] = data;
    return data;
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _saveMyUsername() async {
    if (_uid == null) return;
    final u = _myUsernameCtrl.text.trim();
    if (u.isEmpty) {
      _showSnackBar('Pick a username first');
      return;
    }
    try {
      await _fs.upsertUser(uid: _uid!, displayName: 'Anonymous', username: u);
      if (!mounted) return;
      _showSnackBar('Username set to @$u');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Could not save: $e');
    }
  }

  Future<void> _sendRequest() async {
    if (_uid == null) return;
    final username = _addUsernameCtrl.text.trim();
    if (username.isEmpty) {
      _showSnackBar('Enter a username');
      return;
    }

    try {
      final toUid = await _fs.getUidByUsername(username);
      if (toUid == null) {
        _showSnackBar('No user "$username".');
        return;
      }
      if (toUid == _uid) {
        _showSnackBar('You cannot add yourself');
        return;
      }

      await _fs.sendFriendRequest(fromUid: _uid!, toUid: toUid);
      if (!mounted) return;
      _showSnackBar('Request sent to @$username');
      _addUsernameCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Could not send: $e');
    }
  }

  Future<void> _accept(String friendUid) async {
    if (_uid == null) return;
    try {
      await _fs.acceptFriendship(uid: _uid!, friendUid: friendUid);
      if (!mounted) return;
      _showSnackBar('Accepted');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error: $e');
    }
  }

  Future<void> _remove(String friendUid) async {
    if (_uid == null) return;
    try {
      await _fs.removeFriend(uid: _uid!, friendUid: friendUid);
      if (!mounted) return;
      _showSnackBar('Removed');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error: $e');
    }
  }

  Future<void> _ping(String friendUid) async {
    if (_uid == null) return;
    _pingNoteCtrl.clear();
    final note = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send a PING'),
        content: TextField(
          controller: _pingNoteCtrl,
          maxLength: 80,
          decoration: const InputDecoration(
            labelText: 'Optional note',
            hintText: 'e.g., how are you?',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, _pingNoteCtrl.text.trim()), child: const Text('Send')),
        ],
      ),
    );

    if (!mounted) return;
    try {
      await _fs.sendPing(fromUid: _uid!, toUid: friendUid, note: (note ?? '').isEmpty ? null : note);
      if (!mounted) return;
      _showSnackBar('PING sent');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Could not ping: $e');
    }
  }

  String _pairId(String a, String b) {
    final x = [a, b]..sort();
    return '${x[0]}__${x[1]}';
  }

  String _todayDayKeyWithOffset() {
    final offsetMinutes = DateTime.now().timeZoneOffset.inMinutes;
    final nowLocalAsUtc = DateTime.now().toUtc().add(Duration(minutes: offsetMinutes));
    return DateFormat('yyyy-MM-dd').format(nowLocalAsUtc);
  }

  Future<String> _getSuggestion(String mood, List<String> items) async {
    Map<String, String>? prefs;
    if (_uid != null) {
      try {
        final snap = await _fs.getUser(_uid!);
        final data = snap.data();
        prefs = (data?['personalPreferences'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(key, value.toString()),
        );
      } catch (_) {}
    }

    return OpenAIService.suggest(
      apiKey: _apiKey.isEmpty ? null : _apiKey,
      mood: mood,
      items: items,
      uid: _uid,
      userPreferences: prefs,
    );
  }

  Future<void> _runSuggestionAndTimer({
    required String friendUid,
    required String mood,
    required List<String> items,
    required String dayKey,
  }) async {
    final suggestion = await _getSuggestion(mood, items);

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(context).colorScheme;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [kGlassDark.withOpacity(0.95), kGlassDark.withOpacity(0.9)]
                  : [kGlassLight.withOpacity(0.98), kGlassLight.withOpacity(0.95)],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: cs.primary.withOpacity(0.3), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [cs.primary, cs.secondary]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.verified_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text('Today\'s suggestion', style: Theme.of(ctx).textTheme.titleLarge),
                ],
              ),
              const SizedBox(height: 16),
              Text(suggestion, style: Theme.of(ctx).textTheme.bodyLarge),
              const SizedBox(height: 20),
              ActionTimer(
                initialSeconds: 60,
                options: const [60, 120, 300],
                onComplete: () async {
                  await _fs.submitStreakCheckin(
                    uid: _uid!,
                    friendUid: friendUid,
                    mood: mood,
                    items: items,
                    suggestion: suggestion,
                    dayKeyOverride: dayKey,
                  );
                  if (!mounted) return;
                  Navigator.of(ctx).pop();
                  _showSnackBar('Nice work — check-in saved');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendReaction({
    required String toUid,
    required String reaction,
    required String originalSummary,
  }) async {
    if (_uid == null) return;
    
    try {
      final inbox = _db.collection('pings').doc(toUid).collection('inbox').doc();
      await inbox.set({
        'pingId': inbox.id,
        'type': 'reaction',
        'fromUid': _uid!,
        'toUid': toUid,
        'reaction': reaction,
        'note': reaction,
        'originalSummary': originalSummary,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sent: $reaction'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not send: $e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showReactionPicker({
    required BuildContext context,
    required String toUid,
    required String summary,
    required ColorScheme cs,
    required bool isDark,
  }) {
    final reactions = [
      {'text': 'I get that feeling! 💙', 'icon': Icons.favorite_rounded},
      {'text': 'I got the same suggestion!', 'icon': Icons.lightbulb_rounded},
      {'text': 'You got this! 💪', 'icon': Icons.emoji_emotions_rounded},
      {'text': 'Proud of you!', 'icon': Icons.celebration_rounded},
      {'text': 'Sending good vibes ✨', 'icon': Icons.auto_awesome_rounded},
      {'text': 'That\'s awesome!', 'icon': Icons.thumb_up_rounded},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [kGlassDark.withOpacity(0.95), kGlassDark.withOpacity(0.9)]
                  : [kGlassLight.withOpacity(0.98), kGlassLight.withOpacity(0.95)],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: cs.primary.withOpacity(0.3), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [cs.primary, cs.secondary]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Send a quick reaction',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ListView.separated(
                shrinkWrap: true,
                itemCount: reactions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final reaction = reactions[i];
                  return InkWell(
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _sendReaction(
                        toUid: toUid,
                        reaction: reaction['text'] as String,
                        originalSummary: summary,
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.black.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            reaction['icon'] as IconData,
                            color: cs.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              reaction['text'] as String,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: cs.onSurface.withOpacity(0.3),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_initializing) {
      return Scaffold(
        appBar: AppBar(title: const Text('Friends & Pings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Friends & Pings')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not create a user.\n${_authErrorMsg ?? ''}',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Friends & Pings'),
        backgroundColor: Colors.transparent,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.people_rounded), text: 'Friends'),
            Tab(icon: Icon(Icons.rss_feed_rounded), text: 'Feed'),
            Tab(icon: Icon(Icons.inbox_rounded), text: 'Inbox'),
          ],
        ),
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
              if (_usingLocalUid)
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: cs.onPrimaryContainer),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Using local test ID. Switch to real Auth later.',
                          style: TextStyle(color: cs.onPrimaryContainer, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              _buildUsernameSection(cs, isDark),
              const SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildFriendsTab(cs, isDark),
                    _buildFeedTab(cs, isDark),
                    _buildInboxTab(cs, isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUsernameSection(ColorScheme cs, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [kGlassDark.withOpacity(0.7), kGlassDark.withOpacity(0.5)]
              : [kGlassLight.withOpacity(0.9), kGlassLight.withOpacity(0.7)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.primary.withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _myUsernameCtrl,
                  decoration: InputDecoration(
                    labelText: 'My username',
                    hintText: 'e.g., noura',
                    prefixIcon: Icon(Icons.alternate_email_rounded, color: cs.primary),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _saveMyUsername,
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
                child: const Text('Save'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _addUsernameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Add friend by username',
                    hintText: 'e.g., friendname',
                    prefixIcon: Icon(Icons.person_add_rounded, color: cs.secondary),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _sendRequest,
                style: FilledButton.styleFrom(
                  backgroundColor: cs.secondary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Add'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFriendsTab(ColorScheme cs, bool isDark) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _fs.friendshipsStream(_uid!),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people_outline, size: 64, color: cs.onSurface.withOpacity(0.3)),
                const SizedBox(height: 16),
                Text(
                  'No friends yet',
                  style: TextStyle(fontSize: 18, color: cs.onSurface.withOpacity(0.6)),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add a friend to get started',
                  style: TextStyle(fontSize: 14, color: cs.onSurface.withOpacity(0.5)),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final d = docs[i];
            final friendUid = d.id;
            final status = (d.data()['status'] as String?) ?? 'pending';

            return FutureBuilder<Map<String, dynamic>?>(
              future: _getUser(friendUid),
              builder: (context, userSnap) {
                final u = userSnap.data;
                final name = (u?['displayName'] as String?) ?? 'Unknown';
                final uname = (u?['username'] as String?) ?? 'unknown';

                return _buildFriendCard(
                  cs: cs,
                  isDark: isDark,
                  name: name,
                  username: uname,
                  friendUid: friendUid,
                  status: status,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFriendCard({
    required ColorScheme cs,
    required bool isDark,
    required String name,
    required String username,
    required String friendUid,
    required String status,
  }) {
    return FutureBuilder<bool>(
      future: _isTrustedPerson(friendUid),
      builder: (context, trustedSnap) {
        final isTrusted = trustedSnap.data ?? false;
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? kGlassDark.withOpacity(0.4) : kGlassLight.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isTrusted 
                  ? const Color(0xFFFF6B9D).withOpacity(0.5)
                  : (isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.5)),
              width: isTrusted ? 2 : 1.5,
            ),
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: cs.primaryContainer,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                  if (isTrusted)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: TrustedPersonBadge(),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isTrusted) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF6B9D), Color(0xFFFFB6C1)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Trusted',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@$username • $status',
                      style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.6)),
                    ),
                  ],
                ),
              ),
              _buildFriendActions(cs, friendUid, status),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _isTrustedPerson(String friendUid) async {
    if (_uid == null) return false;
    
    try {
      final snap = await _fs.getUser(_uid!);
      final data = snap.data();
      final prefs = data?['personalPreferences'] as Map<String, dynamic>?;
      final trustedUsername = prefs?['trustedPerson'] as String?;
      
      if (trustedUsername == null || trustedUsername.isEmpty) return false;
      
      final trustedUid = await _fs.getUidByUsername(trustedUsername);
      return trustedUid == friendUid;
    } catch (_) {
      return false;
    }
  }

  Widget _buildFriendActions(ColorScheme cs, String friendUid, String status) {
    if (status == 'incoming') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => _accept(friendUid),
            icon: const Icon(Icons.check_circle_rounded, color: Colors.green),
            tooltip: 'Accept',
          ),
          IconButton(
            onPressed: () => _remove(friendUid),
            icon: Icon(Icons.cancel_rounded, color: cs.error),
            tooltip: 'Decline',
          ),
        ],
      );
    } else if (status == 'pending') {
      return TextButton(
        onPressed: () => _remove(friendUid),
        child: const Text('Cancel'),
      );
    } else {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StreakChip(myUid: _uid!, friendUid: friendUid, fs: _fs),
          IconButton(
            tooltip: 'Start streak',
            icon: const Icon(Icons.local_fire_department_outlined),
            onPressed: () => _startStreak(friendUid),
          ),
          IconButton(
            tooltip: 'PING',
            onPressed: () => _ping(friendUid),
            icon: const Icon(Icons.notifications_active_rounded),
          ),
        ],
      );
    }
  }

  Future<void> _startStreak(String friendUid) async {
    final pairId = _pairId(_uid!, friendUid);
    final dayKey = _todayDayKeyWithOffset();
    final sessionRef = _db.collection('streak_pairs').doc(pairId).collection('sessions').doc(dayKey);

    await _fs.ensureStreakPair(_uid!, friendUid);
    await _fs.startStreakSessionAndInvite(
      fromUid: _uid!,
      toUid: friendUid,
      note: 'Join me for today\'s nudge?',
      tzOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
    );

    final snap = await sessionRef.get();
    final acceptedBy = Map<String, dynamic>.from((snap.data() ?? {})['acceptedBy'] ?? {});
    final friendAccepted = acceptedBy[friendUid] == true;

    if (!friendAccepted) {
      if (!mounted) return;
      _showSnackBar('Invite sent — you will be prompted after your friend accepts.');
      return;
    }

    final mood = await _askFor(context, 'Your mood (1–3 words)');
    if (mood == null || mood.isEmpty) return;
    final itemsCsv = await _askFor(context, 'Nearby items (comma separated)');
    if (itemsCsv == null) return;
    final items = itemsCsv.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    await _runSuggestionAndTimer(friendUid: friendUid, mood: mood, items: items, dayKey: dayKey);
  }


Widget _buildFeedTab(ColorScheme cs, bool isDark) {
  return FutureBuilder<List<String>>(
    future: _fs.listFriendIds(_uid!),
    builder: (context, idsSnap) {
      if (idsSnap.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      final ids = idsSnap.data ?? const <String>[];
      if (ids.isEmpty) {
        return Center(
          child: Text('Add friends to see their shares', style: TextStyle(color: cs.onSurface.withOpacity(0.6))),
        );
      }
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _fs.publicFeedForFriends(friendIds: ids, limit: 50),
        builder: (context, feedSnap) {
          if (feedSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = feedSnap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(child: Text('No shares yet', style: TextStyle(color: cs.onSurface.withOpacity(0.6))));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final d = docs[i];
              final entryId = d.id;
              final data = d.data();
              final authorId = data['authorId'] as String? ?? '';
              final summary = data['publicSummary'] as String? ?? '';
              final ts = (data['createdAt'] as Timestamp?)?.toDate();

              return FutureBuilder<Map<String, dynamic>?>(
                future: _getUser(authorId),
                builder: (ctx, userSnap) {
                  final u = userSnap.data;
                  final name = (u?['displayName'] as String?) ?? '';
                  final who = name.isNotEmpty ? name : 'Someone';

                  return _buildFeedItemCard(
                    cs: cs,
                    isDark: isDark,
                    entryId: entryId,
                    authorId: authorId,
                    authorName: who,
                    summary: summary,
                    timestamp: ts,
                  );
                },
              );
            },
          );
        },
      );
    },
  );
}

// Add this new method to build individual feed items
Widget _buildFeedItemCard({
  required ColorScheme cs,
  required bool isDark,
  required String entryId,
  required String authorId,
  required String authorName,
  required String summary,
  required DateTime? timestamp,
}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: isDark ? kGlassDark.withOpacity(0.4) : kGlassLight.withOpacity(0.6),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.5),
        width: 1.5,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.check_circle_rounded, color: cs.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(authorName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(_compactSummary(summary, max: 240)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(_friendlyTime(timestamp), style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.5))),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // Comments section
        _buildCommentsSection(
          cs: cs,
          isDark: isDark,
          entryId: entryId,
          authorId: authorId,
        ),
        
        // Action buttons row
        if (authorId != _uid) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showReactionPicker(
                    context: context,
                    toUid: authorId,
                    summary: summary,
                    cs: cs,
                    isDark: isDark,
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    side: BorderSide(color: cs.primary.withOpacity(0.5)),
                  ),
                  icon: Icon(Icons.chat_bubble_outline_rounded, size: 18, color: cs.primary),
                  label: Text(
                    'Send reaction',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _addComment(
                    context: context,
                    entryId: entryId,
                    authorId: authorId,
                    cs: cs,
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    backgroundColor: cs.secondary,
                  ),
                  icon: const Icon(Icons.comment_rounded, size: 18),
                  label: const Text(
                    'Comment',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

// Add this method to build the comments section
Widget _buildCommentsSection({
  required ColorScheme cs,
  required bool isDark,
  required String entryId,
  required String authorId,
}) {
  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _db
        .collection('entries_public')
        .doc(entryId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .limit(20)
        .snapshots(),
    builder: (context, commentsSnap) {
      final comments = commentsSnap.data?.docs ?? [];
      
      if (comments.isEmpty) {
        return const SizedBox.shrink();
      }

      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.03)
              : Colors.black.withOpacity(0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cs.outline.withOpacity(0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.comment_rounded, size: 14, color: cs.onSurface.withOpacity(0.5)),
                const SizedBox(width: 6),
                Text(
                  '${comments.length} ${comments.length == 1 ? 'comment' : 'comments'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...comments.map((commentDoc) {
              final commentData = commentDoc.data();
              final commenterId = commentData['fromUid'] as String? ?? '';
              final commentText = commentData['text'] as String? ?? '';
              final commentTs = (commentData['createdAt'] as Timestamp?)?.toDate();

              return FutureBuilder<Map<String, dynamic>?>(
                future: _getUser(commenterId),
                builder: (ctx, userSnap) {
                  final u = userSnap.data;
                  final commenterName = (u?['displayName'] as String?) ?? 'Someone';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: cs.primaryContainer,
                          child: Text(
                            commenterName.isNotEmpty ? commenterName[0].toUpperCase() : '?',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    commenterName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _friendlyTime(commentTs),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: cs.onSurface.withOpacity(0.4),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                commentText,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: cs.onSurface.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            }).toList(),
          ],
        ),
      );
    },
  );
}

// Add this method to handle adding comments
Future<void> _addComment({
  required BuildContext context,
  required String entryId,
  required String authorId,
  required ColorScheme cs,
}) async {
  final controller = TextEditingController();
  
  final comment = await showDialog<String?>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Add a comment'),
      content: TextField(
        controller: controller,
        maxLength: 200,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: 'Write something supportive...',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: const Text('Post'),
        ),
      ],
    ),
  );

  if (comment == null || comment.isEmpty) return;

  try {
    final commentRef = _db
        .collection('entries_public')
        .doc(entryId)
        .collection('comments')
        .doc();
    
    await commentRef.set({
      'commentId': commentRef.id,
      'fromUid': _uid!,
      'toUid': authorId,
      'text': comment,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Send notification to the author
    if (authorId != _uid) {
      final userSnap = await _fs.getUser(_uid!);
      final userData = userSnap.data();
      final myUsername = userData?['username'] as String? ?? 'Someone';
      
      final inbox = _db.collection('pings').doc(authorId).collection('inbox').doc();
      await inbox.set({
        'pingId': inbox.id,
        'type': 'comment',
        'fromUid': _uid!,
        'toUid': authorId,
        'entryId': entryId,
        'commentText': comment,
        'fromUsername': myUsername,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    if (!mounted) return;
    _showSnackBar('Comment posted!');
  } catch (e) {
    if (!mounted) return;
    _showSnackBar('Could not post comment: $e');
  }
}
  Widget _buildInboxTab(ColorScheme cs, bool isDark) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _fs.pingsInboxStream(_uid!),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox_outlined, size: 64, color: cs.onSurface.withOpacity(0.3)),
                const SizedBox(height: 16),
                Text('No pings yet', style: TextStyle(fontSize: 18, color: cs.onSurface.withOpacity(0.6))),
              ],
            ),
          );
        }
        
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final d = docs[i];
            final data = d.data();
            final type = data['type'] as String? ?? 'ping';

            if (type == 'reaction') {
              return _buildReactionCard(cs, isDark, d, data);
            }
            
            if (type == 'trusted_person_notification') {
              return _buildTrustedPersonNotificationCard(cs, isDark, d, data);
            }
            
            if (type == 'streak_invite') {
              return _buildStreakInviteCard(cs, isDark, d, data);
            }

            if (type == 'comment') {
              return _buildCommentNotificationCard(cs, isDark, d, data);
            }

            return _buildPingCard(cs, isDark, d, data);
          },
        );
      },
    );
  }

  Widget _buildReactionCard(ColorScheme cs, bool isDark, QueryDocumentSnapshot d, Map<String, dynamic> data) {
    final fromUid = data['fromUid'] as String? ?? '';
    final reaction = data['reaction'] as String? ?? '';
    final originalSummary = data['originalSummary'] as String? ?? '';
    final read = data['read'] as bool? ?? false;
    final ts = (data['createdAt'] as Timestamp?)?.toDate();

    return FutureBuilder<Map<String, dynamic>?>(
      future: _getUser(fromUid),
      builder: (ctx, userSnap) {
        final u = userSnap.data;
        final name = u?['displayName'] ?? 'Someone';
        final uname = u?['username'] ?? '';
        
        return InkWell(
          onTap: () => _fs.markPingRead(recipientUid: _uid!, pingId: d.id),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: read
                    ? [
                        (isDark ? kGlassDark : kGlassLight).withOpacity(0.3),
                        (isDark ? kGlassDark : kGlassLight).withOpacity(0.3),
                      ]
                    : [
                        kPrimaryCyan.withOpacity(0.1),
                        kSecondaryPurple.withOpacity(0.1),
                      ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: read
                    ? (isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.3))
                    : cs.primary.withOpacity(0.4),
                width: read ? 1 : 2,
              ),
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
                          colors: [kPrimaryCyan, kSecondaryPurple],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$name reacted to your moment',
                            style: TextStyle(
                              fontWeight: read ? FontWeight.w500 : FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          if (uname.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              '@$uname',
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurface.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Text(
                      _friendlyTime(ts),
                      style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.5)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: cs.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    reaction,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                  ),
                ),
                if (originalSummary.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'On: ${_compactSummary(originalSummary, max: 60)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withOpacity(0.5),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrustedPersonNotificationCard(
    ColorScheme cs,
    bool isDark,
    QueryDocumentSnapshot d,
    Map<String, dynamic> data,
  ) {
    final fromUid = data['fromUid'] as String? ?? '';
    final fromUsername = data['fromUsername'] as String? ?? '';
    final summary = data['summary'] as String? ?? '';
    final read = data['read'] as bool? ?? false;
    final ts = (data['createdAt'] as Timestamp?)?.toDate();

    return InkWell(
      onTap: () => _fs.markPingRead(recipientUid: _uid!, pingId: d.id),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: read
                ? [
                    (isDark ? kGlassDark : kGlassLight).withOpacity(0.3),
                    (isDark ? kGlassDark : kGlassLight).withOpacity(0.3),
                  ]
                : [
                    const Color(0xFFFF6B9D).withOpacity(0.15),
                    const Color(0xFFFFB6C1).withOpacity(0.15),
                  ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: read
                ? (isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.3))
                : const Color(0xFFFF6B9D).withOpacity(0.4),
            width: read ? 1 : 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B9D), Color(0xFFFFB6C1)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '@$fromUsername shared a moment',
                    style: TextStyle(
                      fontWeight: read ? FontWeight.w500 : FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _compactSummary(summary, max: 80),
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _friendlyTime(ts),
              style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.5)),
            ),
          ],
        ),
      ),
    );
  }


// PATH: lib/screens/friends_screen.dart
// Add this method to handle comment notification cards (add after _buildTrustedPersonNotificationCard around line 700)

Widget _buildCommentNotificationCard(
  ColorScheme cs,
  bool isDark,
  QueryDocumentSnapshot d,
  Map<String, dynamic> data,
) {
  final fromUid = data['fromUid'] as String? ?? '';
  final fromUsername = data['fromUsername'] as String? ?? '';
  final commentText = data['commentText'] as String? ?? '';
  final read = data['read'] as bool? ?? false;
  final ts = (data['createdAt'] as Timestamp?)?.toDate();

  return InkWell(
    onTap: () => _fs.markPingRead(recipientUid: _uid!, pingId: d.id),
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: read
              ? [
                  (isDark ? kGlassDark : kGlassLight).withOpacity(0.3),
                  (isDark ? kGlassDark : kGlassLight).withOpacity(0.3),
                ]
              : [
                  kSecondaryPurple.withOpacity(0.1),
                  kPrimaryCyan.withOpacity(0.1),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: read
              ? (isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.3))
              : cs.secondary.withOpacity(0.4),
          width: read ? 1 : 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [kSecondaryPurple, kPrimaryCyan],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.comment_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '@$fromUsername commented on your post',
                  style: TextStyle(
                    fontWeight: read ? FontWeight.w500 : FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '"$commentText"',
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withOpacity(0.7),
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _friendlyTime(ts),
            style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.5)),
          ),
        ],
      ),
    ),
  );
}




  Widget _buildStreakInviteCard(ColorScheme cs, bool isDark, QueryDocumentSnapshot d, Map<String, dynamic> data) {
    final fromUid = data['fromUid'] as String? ?? '';
    final note = data['note'] as String? ?? '';
    final pairId = data['pairId'] as String?;
    final inviteDayKey = data['dayKey'] as String?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kAccentCoral.withOpacity(0.15), kSecondaryPurple.withOpacity(0.15)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kAccentCoral.withOpacity(0.5), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [kAccentCoral, cs.secondary]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_fire_department, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FutureBuilder<Map<String, dynamic>?>(
                  future: _getUser(fromUid),
                  builder: (ctx, userSnap) {
                    final uname = userSnap.data?['username'] as String? ?? 'friend';
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Streak invite', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 2),
                        Text('From @$uname', style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.7))),
                        if (note.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(note, style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.6))),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _acceptStreakInvite(fromUid, d.id, pairId, inviteDayKey),
              style: FilledButton.styleFrom(backgroundColor: cs.secondary),
              child: const Text('Join streak'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptStreakInvite(String fromUid, String pingId, String? pairId, String? inviteDayKey) async {
    try {
      final pid = pairId ?? _pairId(_uid!, fromUid);
      final dk = inviteDayKey ?? _todayDayKeyWithOffset();
      final sessionRef = _db.collection('streak_pairs').doc(pid).collection('sessions').doc(dk);

      await sessionRef.set({
        'acceptedBy.${_uid!}': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}

    final mood = await _askFor(context, 'Your mood (1–3 words)');
    if (mood == null || mood.isEmpty) return;
    final itemsCsv = await _askFor(context, 'Nearby items (comma separated)');
    if (itemsCsv == null) return;
    final items = itemsCsv.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    await _runSuggestionAndTimer(
      friendUid: fromUid,
      mood: mood,
      items: items,
      dayKey: inviteDayKey ?? _todayDayKeyWithOffset(),
    );

    await _fs.markPingRead(recipientUid: _uid!, pingId: pingId);

    if (!mounted) return;
    _showSnackBar('Joined today\'s streak');
  }

  Widget _buildPingCard(ColorScheme cs, bool isDark, QueryDocumentSnapshot d, Map<String, dynamic> data) {
    final fromUid = data['fromUid'] as String? ?? '';
    final note = data['note'] as String? ?? '';
    final read = data['read'] as bool? ?? false;
    final ts = (data['createdAt'] as Timestamp?)?.toDate();

    return FutureBuilder<Map<String, dynamic>?>(
      future: _getUser(fromUid),
      builder: (ctx, userSnap) {
        final u = userSnap.data;
        final name = u?['displayName'] ?? 'Someone';
        final uname = u?['username'] ?? '';
        return InkWell(
          onTap: () => _fs.markPingRead(recipientUid: _uid!, pingId: d.id),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: read
                  ? (isDark ? kGlassDark.withOpacity(0.3) : kGlassLight.withOpacity(0.5))
                  : (isDark ? kGlassDark.withOpacity(0.5) : kGlassLight.withOpacity(0.8)),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: read
                    ? (isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.3))
                    : cs.primary.withOpacity(0.4),
                width: read ? 1 : 2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: read ? cs.surfaceVariant : cs.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    read ? Icons.mark_email_read : Icons.mark_email_unread,
                    color: read ? cs.onSurfaceVariant : cs.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PING from $name${uname.isNotEmpty ? ' (@$uname)' : ''}',
                        style: TextStyle(fontWeight: read ? FontWeight.w500 : FontWeight.w700, fontSize: 15),
                      ),
                      if (note.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(note, style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.7))),
                      ] else ...[
                        const SizedBox(height: 4),
                        Text('Tap to mark as read', style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.5))),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(_friendlyTime(ts), style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.5))),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String?> _askFor(BuildContext ctx, String label) async {
    final c = TextEditingController();
    return showDialog<String?>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: Text(label),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, null), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dCtx, c.text.trim()), child: const Text('OK')),
        ],
      ),
    );
  }

  String _friendlyTime(DateTime? t) {
    if (t == null) return '';
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  String _compactSummary(String s, {int max = 90}) {
    var t = s.trim();
    final m = RegExp(
      r'^\s*felt\s+(.+?)\s+and\s+was\s+recommended:\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(t);
    if (m != null) {
      final mood = m.group(1)!.trim();
      final rec = m.group(2)!.trim();
      t = '$mood → $rec';
    }
    t = t.replaceAll(RegExp(r'\s+'), ' ');
    if (t.length > max) t = '${t.substring(0, max - 1)}…';
    return t;
  }
}


// TrustedPersonBadge widget
class TrustedPersonBadge extends StatelessWidget {
  const TrustedPersonBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B9D), Color(0xFFFFB6C1)],
        ),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: const Icon(
        Icons.favorite,
        color: Colors.white,
        size: 12,
      ),
    );
  }
}