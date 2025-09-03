// PATH: lib/screens/friends_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../widgets/friends_shares_feed.dart';

import '../services/firestore_service.dart';
import '../widgets/streak_chip.dart'; // <-- ADDED

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _fs = FirestoreService();

  final _myUsernameCtrl = TextEditingController();
  final _addUsernameCtrl = TextEditingController();
  final _pingNoteCtrl = TextEditingController();

  final Map<String, Map<String, dynamic>?> _userCache = {};

  String? _uid; // Firebase uid or local fallback
  bool _usingLocalUid = false; // shows banner
  String? _authErrorMsg;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _initIdentity();
  }

  Future<void> _initIdentity() async {
    String? uid;
    // 1) Try Firebase Anonymous Auth
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

    // 2) Persistent local UID fallback (DEV)
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
        // 3) Last-resort in-memory uid (session only)
        uid = const Uuid().v4();
        _usingLocalUid = true;
      }
    }

    _uid = uid;

    // Load any profile
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

  @override
  void dispose() {
    _myUsernameCtrl.dispose();
    _addUsernameCtrl.dispose();
    _pingNoteCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _getUser(String uid) async {
    if (_userCache.containsKey(uid)) return _userCache[uid];
    final snap = await _fs.getUser(uid);
    final data = snap.data();
    _userCache[uid] = data;
    return data;
  }

  Future<void> _saveMyUsername() async {
    if (_uid == null) return;
    final u = _myUsernameCtrl.text.trim();
    if (u.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a username first')),
      );
      return;
    }
    try {
      await _fs.upsertUser(
        uid: _uid!,
        displayName: 'Anonymous',
        username: u,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Username set to @$u')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  Future<void> _sendRequest() async {
    if (_uid == null) return;
    final username = _addUsernameCtrl.text.trim();
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a username')),
      );
      return;
    }

    try {
      final toUid = await _fs.getUidByUsername(username);
      if (toUid == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No user “$username”.')));
        return;
      }
      if (toUid == _uid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You cannot add yourself')),
        );
        return;
      }

      await _fs.sendFriendRequest(fromUid: _uid!, toUid: toUid);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Request sent to @$username')));
      _addUsernameCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not send: $e')));
    }
  }

  Future<void> _accept(String friendUid) async {
    if (_uid == null) return;
    try {
      await _fs.acceptFriendship(uid: _uid!, friendUid: friendUid);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Accepted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _remove(String friendUid) async {
    if (_uid == null) return;
    try {
      await _fs.removeFriend(uid: _uid!, friendUid: friendUid);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Removed')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
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
          TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, _pingNoteCtrl.text.trim()),
              child: const Text('Send')),
        ],
      ),
    );

    if (!mounted) return;
    try {
      await _fs.sendPing(
        fromUid: _uid!,
        toUid: friendUid,
        note: (note ?? '').isEmpty ? null : note,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('PING sent')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not ping: $e')));
    }
  }

  // Simple input helper for streak invite acceptance
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
              'Couldn’t create a user.\n${_authErrorMsg ?? ''}',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends & Pings'),
        backgroundColor: cs.surface,
        surfaceTintColor: cs.surfaceTint,
      ),
      body: Column(
        children: [
          if (_usingLocalUid)
            MaterialBanner(
              content: const Text(
                'Using local test ID (Firebase Auth not available). You can add friends & ping now. '
                'Switch to real Auth later.',
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
                  child: const Text('OK'),
                ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // My username
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _myUsernameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'My username',
                          hintText: 'e.g., noura',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                        onPressed: _saveMyUsername, child: const Text('Save')),
                  ],
                ),
                const SizedBox(height: 16),

                // Add by username
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _addUsernameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Add friend by username',
                          hintText: 'e.g., friendname',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _sendRequest,
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('Add'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Friendships
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _fs.friendshipsStream(_uid!),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('No friends yet.'));
                }

                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final d = docs[i];
                    final friendUid = d.id;
                    final status =
                        (d.data()['status'] as String?) ?? 'pending';

                    return FutureBuilder<Map<String, dynamic>?>(
                      future: _getUser(friendUid),
                      builder: (context, userSnap) {
                        final u = userSnap.data;
                        final name =
                            (u?['displayName'] as String?) ?? 'Unknown';
                        final uname =
                            (u?['username'] as String?) ?? 'unknown';

                        Widget trailing;
                        if (status == 'incoming') {
                          trailing = Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                  onPressed: () => _accept(friendUid),
                                  child: const Text('Accept')),
                              TextButton(
                                  onPressed: () => _remove(friendUid),
                                  child: const Text('Decline')),
                            ],
                          );
                        } else if (status == 'pending') {
                          trailing = TextButton(
                              onPressed: () => _remove(friendUid),
                              child: const Text('Cancel'));
                        } else {
                          trailing = Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Streak chip + start streak
                              StreakChip(myUid: _uid!, friendUid: friendUid, fs: _fs),
                              const SizedBox(width: 6),
                              IconButton(
                                tooltip: 'Start streak',
                                icon: const Icon(Icons.local_fire_department_outlined),
                                onPressed: () async {
                                  await _fs.startStreakSessionAndInvite(
                                    fromUid: _uid!,
                                    toUid: friendUid,
                                    note: 'Join me for today’s nudge?',
                                    tzOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
                                  );
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Streak invite sent')),
                                  );
                                },
                              ),

                              // Existing actions
                              IconButton(
                                tooltip: 'PING',
                                onPressed: () => _ping(friendUid),
                                icon: const Icon(
                                    Icons.notifications_active_rounded),
                              ),
                              TextButton(
                                  onPressed: () => _remove(friendUid),
                                  child: const Text('Remove')),
                            ],
                          );
                        }

                        return ListTile(
                          leading: CircleAvatar(
                              child: Text(name.isNotEmpty
                                  ? name[0].toUpperCase()
                                  : '?')),
                          title: Text(name),
                          subtitle: Text('@$uname • $status'),
                          trailing: trailing,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),

          // ---- Friends’ feed (shares) ----
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
            child: Row(
              children: [
                Text('Friends’ shares',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: 8),
                const Icon(Icons.rss_feed_rounded, size: 18),
              ],
            ),
          ),
          SizedBox(
            height: 220,
            child: FutureBuilder<List<String>>(
              future: _fs.listFriendIds(_uid!),
              builder: (context, idsSnap) {
                if (idsSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final ids = idsSnap.data ?? const <String>[];
                if (ids.isEmpty) {
                  return const Center(
                      child: Text('Add friends to see their shares.'));
                }
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream:
                      _fs.publicFeedForFriends(friendIds: ids, limit: 50),
                  builder: (context, feedSnap) {
                    if (feedSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = feedSnap.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Center(child: Text('No shares yet.'));
                    }
                    return ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final d = docs[i].data();
                        final authorId = d['authorId'] as String? ?? '';
                        final summary =
                            d['publicSummary'] as String? ?? '';
                        final ts =
                            (d['createdAt'] as Timestamp?)?.toDate();

                        return FutureBuilder<Map<String, dynamic>?>(
                          future: _getUser(authorId),
                          builder: (ctx, userSnap) {
                            final u = userSnap.data;
                            final name = (u?['displayName'] as String?) ?? '';
                            final uname =
                                (u?['username'] as String?) ?? '';
                            final who = name.isNotEmpty
                                ? name
                                : (uname.isNotEmpty ? '@$uname' : 'Someone');

                            return ListTile(
                              leading:
                                  const Icon(Icons.check_circle_rounded),
                              title: Text(who),
                              subtitle: Text(summary),
                              trailing: Text(_friendlyTime(ts)),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),

          // Inbox (includes streak_invite handling)
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
            child: Row(
              children: [
                Text('Inbox', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: 8),
                const Icon(Icons.inbox_rounded, size: 18),
              ],
            ),
          ),
          SizedBox(
            height: 180,
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _fs.pingsInboxStream(_uid!),
              builder: (context, snap) {
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('No pings yet.'));
                }
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final d = docs[i];
                    final data = d.data();
                    final type = data['type'] as String? ?? 'ping';
                    final ts = (data['createdAt'] as Timestamp?)?.toDate();

                    if (type == 'streak_invite') {
                      final fromUid = data['fromUid'] as String? ?? '';
                      final note = data['note'] as String? ?? '';

                      return ListTile(
                        leading: const Icon(Icons.local_fire_department),
                        title: const Text('Streak invite'),
                        subtitle: FutureBuilder<Map<String, dynamic>?>(
                          future: _getUser(fromUid),
                          builder: (ctx, userSnap) {
                            final uname =
                                userSnap.data?['username'] as String? ?? 'friend';
                            final base = 'From @$uname';
                            return Text(note.isEmpty ? base : '$base • $note');
                          },
                        ),
                        trailing: FilledButton(
                          onPressed: () async {
                            final mood =
                                await _askFor(context, 'Your mood (1–3 words)');
                            if (mood == null || mood.isEmpty) return;
                            final itemsCsv = await _askFor(
                                context, 'Nearby items (comma separated)');
                            if (itemsCsv == null) return;
                            final items = itemsCsv
                                .split(',')
                                .map((s) => s.trim())
                                .where((s) => s.isNotEmpty)
                                .toList();

                            // For now, simple placeholder suggestion.
                            final suggestion = '2-min grounding together';

                            await _fs.submitStreakCheckin(
                              uid: _uid!,
                              friendUid: fromUid,
                              mood: mood,
                              items: items,
                              suggestion: suggestion,
                            );
                            await _fs.markPingRead(
                                recipientUid: _uid!, pingId: d.id);

                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Joined today’s streak')),
                            );
                          },
                          child: const Text('Join'),
                        ),
                      );
                    }

                    // Default PING tile
                    final fromUid = data['fromUid'] as String? ?? '';
                    final note = data['note'] as String? ?? '';
                    final read = data['read'] as bool? ?? false;

                    return FutureBuilder<Map<String, dynamic>?>(
                      future: _getUser(fromUid),
                      builder: (ctx, userSnap) {
                        final u = userSnap.data;
                        final name = u?['displayName'] ?? 'Someone';
                        final uname = u?['username'] ?? '';
                        return ListTile(
                          leading: Icon(read
                              ? Icons.mark_email_read
                              : Icons.mark_email_unread),
                          title: Text(
                              'PING from $name${uname.isNotEmpty ? ' (@$uname)' : ''}'),
                          subtitle:
                              Text(note.isEmpty ? 'Tap to mark read' : note),
                          trailing: Text(_friendlyTime(ts)),
                          onTap: () => _fs.markPingRead(
                              recipientUid: _uid!, pingId: d.id),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
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
}
