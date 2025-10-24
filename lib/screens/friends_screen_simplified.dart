// PATH: lib/screens/friends_screen_simplified.dart (NEW - REPLACEMENT)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../widgets/ghost_mode_button.dart';
import '../services/firestore_service.dart';
import 'chat_screen_updated.dart';

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

class FriendsScreenSimplified extends StatefulWidget {
  const FriendsScreenSimplified({super.key});

  @override
  State<FriendsScreenSimplified> createState() => _FriendsScreenSimplifiedState();
}

class _FriendsScreenSimplifiedState extends State<FriendsScreenSimplified> {
  final _fs = FirestoreService();
  final _db = FirebaseFirestore.instance;

  final _myUsernameCtrl = TextEditingController();
  final _addUsernameCtrl = TextEditingController();

  final Map<String, Map<String, dynamic>?> _userCache = {};

  String? _uid;
  bool _usingLocalUid = false;
  String? _authErrorMsg;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _initIdentity();
  }

  @override
  void dispose() {
    _myUsernameCtrl.dispose();
    _addUsernameCtrl.dispose();
    super.dispose();
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

  String _pairId(String a, String b) {
    final x = [a, b]..sort();
    return '${x[0]}__${x[1]}';
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_initializing) {
      return Scaffold(
        appBar: AppBar(title: const Text('Friends')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Friends')),
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
        title: const Text('Friends & Chats'),
        backgroundColor: Colors.transparent,
        actions: [
          const GhostModeButton(compact: true),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Username setup section
                _buildUsernameSection(cs, isDark),
                const SizedBox(height: 32),

                // Active chats section
                Text(
                  'Active Chats',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                _buildChatsList(cs, isDark),

                const SizedBox(height: 32),

                // Friends list section
                Text(
                  'My Friends',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                _buildFriendsList(cs, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUsernameSection(ColorScheme cs, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
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

  Widget _buildChatsList(ColorScheme cs, bool isDark) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _fs.friendshipsStream(_uid!),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final docs = snap.data?.docs ?? [];
        final acceptedFriends = docs
            .where((d) => (d.data()['status'] ?? 'pending') == 'accepted')
            .toList();

        if (acceptedFriends.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark 
                  ? Colors.white.withOpacity(0.03) 
                  : Colors.black.withOpacity(0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark 
                    ? Colors.white.withOpacity(0.1) 
                    : Colors.black.withOpacity(0.05),
              ),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.chat_outlined, size: 48, color: cs.onSurface.withOpacity(0.3)),
                  const SizedBox(height: 12),
                  Text(
                    'No active chats yet',
                    style: TextStyle(color: cs.onSurface.withOpacity(0.6)),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: acceptedFriends.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final d = acceptedFriends[i];
            final friendUid = d.id;

            return FutureBuilder<Map<String, dynamic>?>(
              future: _getUser(friendUid),
              builder: (context, userSnap) {
                final u = userSnap.data;
                final name = (u?['displayName'] as String?) ?? 'Unknown';
                final uname = (u?['username'] as String?) ?? 'unknown';

                return _buildChatCard(
                  cs: cs,
                  isDark: isDark,
                  name: name,
                  username: uname,
                  friendUid: friendUid,
                  onTap: () => _openChat(friendUid, name),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildChatCard({
    required ColorScheme cs,
    required bool isDark,
    required String name,
    required String username,
    required String friendUid,
    required VoidCallback onTap,
  }) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(_pairId(_uid!, friendUid))
          .snapshots(),
      builder: (context, chatSnap) {
        final streak = (chatSnap.data?.data()?['streak'] as int?) ?? 0;

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? kGlassDark.withOpacity(0.4) : kGlassLight.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.5),
                width: 1.5,
              ),
            ),
            child: Row(
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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@$username',
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                if (streak > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B9D), Color(0xFFFFB6C1)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_fire_department, size: 16, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          '$streak',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, color: cs.onSurface.withOpacity(0.3)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFriendsList(ColorScheme cs, bool isDark) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _fs.friendshipsStream(_uid!),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark 
                  ? Colors.white.withOpacity(0.03) 
                  : Colors.black.withOpacity(0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark 
                    ? Colors.white.withOpacity(0.1) 
                    : Colors.black.withOpacity(0.05),
              ),
            ),
            child: Center(
              child: Text(
                'No friends yet',
                style: TextStyle(color: cs.onSurface.withOpacity(0.6)),
              ),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
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

                return _buildFriendItemCard(
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

  Widget _buildFriendItemCard({
    required ColorScheme cs,
    required bool isDark,
    required String name,
    required String username,
    required String friendUid,
    required String status,
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
      child: Row(
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '@$username • $status',
                  style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.6)),
                ),
              ],
            ),
          ),
          if (status == 'incoming') ...[
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
          ] else if (status == 'pending') ...[
            TextButton(
              onPressed: () => _remove(friendUid),
              child: const Text('Cancel'),
            ),
          ],
        ],
      ),
    );
  }
}