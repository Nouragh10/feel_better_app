// PATH: lib/screens/chat_screen.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/action_timer.dart';
import 'shared_exercise_screen.dart';

/// ChatScreen
/// Required: chatId
/// Optional: friendUid / friendId (alias), friendName (for header; resolved if missing)
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.chatId,
    this.friendUid,
    this.friendId, // <— alias to support calls from friends_screen.dart
    this.friendName,
  });

  final String chatId;
  final String? friendUid;
  final String? friendId; // alias
  final String? friendName;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final TextEditingController _textCtrl = TextEditingController();
  bool _sending = false;

  String? _myUid;
  String? _partnerUid;
  String? _partnerName;

  ColorScheme get _cs => Theme.of(context).colorScheme;
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    _myUid = _auth.currentUser?.uid;
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolvePartnerMeta());
  }

  Future<void> _resolvePartnerMeta() async {
    try {
      final chatRef = _db.collection('chats').doc(widget.chatId);
      final chatSnap = await chatRef.get();
      final chat = chatSnap.data() ?? {};
      final participants = (chat['participants'] as List?)?.cast<String>() ?? const <String>[];

      _myUid ??= _auth.currentUser?.uid;

      // prefer participants, fall back to friendUid/friendId passed from friends_screen.dart
      if (participants.length == 2) {
        final partner = participants.firstWhere(
          (id) => id != _myUid,
          orElse: () => (widget.friendUid ?? widget.friendId ?? ''),
        );
        _partnerUid = partner.isNotEmpty ? partner : (widget.friendUid ?? widget.friendId ?? '');
      } else {
        _partnerUid ??= widget.friendUid ?? widget.friendId;
      }

      // partner display name
      if (widget.friendName != null && widget.friendName!.trim().isNotEmpty) {
        _partnerName = widget.friendName!.trim();
      } else if ((_partnerUid ?? '').isNotEmpty) {
        try {
          final userSnap = await _db.collection('users').doc(_partnerUid).get();
          final data = userSnap.data();
          final display = (data?['displayName'] as String?)?.trim();
          final uname = (data?['username'] as String?)?.trim();
          _partnerName = (display?.isNotEmpty ?? false)
              ? display
              : ((uname?.isNotEmpty ?? false) ? uname : 'Friend');
        } catch (_) {
          _partnerName ??= 'Friend';
        }
      } else {
        _partnerName ??= 'Friend';
      }

      if (mounted) setState(() {});
    } catch (_) {
      _partnerName ??= widget.friendName ?? 'Friend';
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  // ------------------------ Messaging ------------------------

  Future<void> _sendTextMessage() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _myUid == null) return;

    setState(() => _sending = true);
    try {
      final chatRef = _db.collection('chats').doc(widget.chatId);
      final msgRef = chatRef.collection('messages').doc();

      await msgRef.set({
        'type': 'text',
        'senderId': _myUid,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await chatRef.update({'updatedAt': FieldValue.serverTimestamp()});
      _textCtrl.clear();
    } catch (e) {
      _snack('Could not send: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // -------------------- Exercise Invitations --------------------

  void _showExercisePicker() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _exerciseOption(
                icon: Icons.air_rounded,
                title: 'Breathing Exercise',
                subtitle: '2 minutes • in sync together',
                onTap: () {
                  Navigator.pop(ctx);
                  _initiateExercise('breathing');
                },
              ),
              const SizedBox(height: 12),
              _exerciseOption(
                icon: Icons.self_improvement_rounded,
                title: 'Yoga Session',
                subtitle: '5 minutes • gentle flow',
                onTap: () {
                  Navigator.pop(ctx);
                  _initiateExercise('yoga');
                },
              ),
              const SizedBox(height: 12),
              _exerciseOption(
                icon: Icons.play_circle_outline_rounded,
                title: 'Calm Video',
                subtitle: '3 minutes • soothing clip',
                onTap: () {
                  Navigator.pop(ctx);
                  _initiateExercise('calm_video');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _exerciseOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_cs.primary, _cs.secondary]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _cs.onSurface),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 13, color: _cs.onSurface.withOpacity(0.6))),
              ]),
            ),
            Icon(Icons.arrow_forward_rounded, color: _cs.onSurface.withOpacity(0.3), size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _initiateExercise(String exerciseType) async {
    if (_myUid == null) return;
    try {
      final chatRef = _db.collection('chats').doc(widget.chatId);
      final chatSnap = await chatRef.get();
      final chat = chatSnap.data() ?? {};
      final participants = (chat['participants'] as List?)?.cast<String>() ?? const <String>[];

      if (participants.length != 2) {
        _snack('This feature requires a 1:1 chat.');
        return;
      }

      final activityRef = chatRef.collection('activities').doc();
      final now = FieldValue.serverTimestamp();

      final partMap = <String, dynamic>{};
      for (final uid in participants) {
        partMap[uid] = {'completed': false, 'joinedAt': null, 'completedAt': null};
      }

      await activityRef.set({
        'type': exerciseType,
        'exerciseType': exerciseType,
        'initiatorId': _myUid,
        'status': 'pending',
        'createdAt': now,
        'participants': partMap,
      });

      final msgRef = chatRef.collection('messages').doc();
      await msgRef.set({
        'type': 'exercise_invite',
        'senderId': _myUid,
        'timestamp': now,
        'exerciseType': exerciseType,
        'activityId': activityRef.id,
      });

      await chatRef.update({'updatedAt': now});
    } catch (e) {
      _snack('Could not start exercise: $e');
    }
  }

  Future<void> _joinExerciseAndOpen(String activityId, String exerciseType) async {
    if (_myUid == null) return;
    try {
      final actRef = _db.collection('chats').doc(widget.chatId).collection('activities').doc(activityId);
      await actRef.update({
        'status': 'in_progress',
        'participants.${_myUid!}.joinedAt': FieldValue.serverTimestamp(),
      });

      final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => SharedExerciseScreen(
            chatId: widget.chatId,
            activityId: activityId,
            exerciseType: exerciseType,
            partnerName: _partnerName ?? 'Friend', // <— now supported
          ),
        ),
      );

      if (ok == true) {
        await _markCompletedAndMaybeUpdateStreak(activityId, exerciseType);
      }
    } catch (e) {
      _snack('Could not open exercise: $e');
    }
  }

  Future<void> _markCompletedAndMaybeUpdateStreak(String activityId, String exerciseType) async {
    if (_myUid == null) return;

    final chatRef = _db.collection('chats').doc(widget.chatId);
    final actRef = chatRef.collection('activities').doc(activityId);

    await _db.runTransaction((txn) async {
      final actSnap = await txn.get(actRef);
      if (!actSnap.exists) return;

      final data = actSnap.data() as Map<String, dynamic>;
      final participants = (data['participants'] as Map<String, dynamic>?) ?? {};
      final others = participants.keys.where((k) => k != _myUid).toList();
      final otherUid = others.isNotEmpty ? others.first : null;

      // Mark me completed
      txn.update(actRef, {
        'participants.${_myUid!}.completed': true,
        'participants.${_myUid!}.completedAt': FieldValue.serverTimestamp(),
      });

      // If friend also completed -> update chat streak
      final friendDone = otherUid != null && (participants[otherUid]?['completed'] == true);

      if (friendDone) {
        txn.update(actRef, {'status': 'completed'});

        final chatSnap = await txn.get(chatRef);
        final chat = chatSnap.data() as Map<String, dynamic>? ?? {};
        final current = (chat['streak'] as int?) ?? 0;
        final longest = (chat['longestStreak'] as int?) ?? 0;
        final lastTs = (chat['lastActivityDate'] as Timestamp?);

        final now = DateTime.now();
        int nextStreak = 1;
        if (lastTs != null) {
          final last = lastTs.toDate();
          final sameDay = _isSameDay(now, last);
          final yesterday = _isYesterday(now, last);
          if (sameDay) {
            nextStreak = current;
          } else if (yesterday) {
            nextStreak = current + 1;
          } else {
            nextStreak = 1;
          }
        }

        final nextLongest = nextStreak > longest ? nextStreak : longest;

        txn.update(chatRef, {
          'streak': nextStreak,
          'longestStreak': nextLongest,
          'lastActivityDate': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final msgRef = chatRef.collection('messages').doc();
        txn.set(msgRef, {
          'type': 'exercise_completed',
          'senderId': _myUid,
          'timestamp': FieldValue.serverTimestamp(),
          'exerciseType': exerciseType,
          'activityId': activityId,
          'note': 'Both friends completed $exerciseType',
        });
      }
    });

    _snack('Marked completed. Nice work!');
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isYesterday(DateTime today, DateTime d) {
    final y = today.subtract(const Duration(days: 1));
    return _isSameDay(y, d);
    }

  // ---------------------------- UI ----------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _db.collection('chats').doc(widget.chatId).snapshots(),
          builder: (context, snap) {
            final chat = snap.data?.data();
            final streak = (chat?['streak'] as int?) ?? 0;
            final longest = (chat?['longestStreak'] as int?) ?? 0;
            final name = _partnerName ?? widget.friendName ?? 'Friend';

            return Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              )),
                      const SizedBox(height: 2),
                      Row(children: [
                        const Icon(Icons.local_fire_department, size: 16, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text('$streak day streak',
                            style: TextStyle(fontSize: 12, color: _cs.onSurface.withOpacity(0.7))),
                        const SizedBox(width: 8),
                        const Text('•', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 8),
                        const Icon(Icons.emoji_events_rounded, size: 14),
                        const SizedBox(width: 4),
                        Text('best $longest',
                            style: TextStyle(fontSize: 12, color: _cs.onSurface.withOpacity(0.7))),
                      ]),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Invite to exercise',
            icon: const Icon(Icons.add_reaction_rounded),
            onPressed: _showExercisePicker,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessagesList()),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    final msgs = _db
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .limit(200);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: msgs.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? const [];
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Say hi to ${_partnerName ?? 'your friend'} and invite them to a quick exercise ✨',
                textAlign: TextAlign.center,
                style: TextStyle(color: _cs.onSurface.withOpacity(0.7)),
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final m = docs[i].data();
            final type = (m['type'] as String?) ?? 'text';
            switch (type) {
              case 'exercise_invite':
                return _exerciseInviteTile(
                  activityId: (m['activityId'] as String?) ?? '',
                  exerciseType: (m['exerciseType'] as String?) ?? 'breathing',
                  senderId: (m['senderId'] as String?) ?? '',
                  ts: m['timestamp'] as Timestamp?,
                );
              case 'exercise_completed':
                return _systemTile(
                    '🎉 Both of you completed ${(m['exerciseType'] as String?) ?? 'an exercise'} today!');
              default:
                return _textTile(
                  text: (m['text'] as String?) ?? '',
                  mine: m['senderId'] == _myUid,
                  ts: m['timestamp'] as Timestamp?,
                );
            }
          },
        );
      },
    );
  }

  Widget _textTile({required String text, required bool mine, Timestamp? ts}) {
    final bubble = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: mine ? _cs.primary.withOpacity(0.18) : _cs.surfaceVariant.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: mine ? _cs.primary.withOpacity(0.35) : _cs.outline.withOpacity(0.15),
          width: 1.5,
        ),
      ),
      child: Text(text, style: TextStyle(color: _cs.onSurface, fontSize: 15, height: 1.4)),
    );

    return Row(
      mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [Flexible(child: bubble)],
    );
  }

  Widget _systemTile(String text) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _cs.secondaryContainer.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text, style: TextStyle(fontSize: 12, color: _cs.onSecondaryContainer)),
      ),
    );
  }

  Widget _exerciseInviteTile({
    required String activityId,
    required String exerciseType,
    required String senderId,
    required Timestamp? ts,
  }) {
    final me = senderId == _myUid;
    final title = switch (exerciseType) {
      'breathing' => 'Breathing exercise',
      'yoga' => 'Yoga session',
      'calm_video' => 'Calm video',
      _ => 'Shared exercise',
    };

    final durLabel = switch (exerciseType) {
      'breathing' => '2 min',
      'yoga' => '5 min',
      'calm_video' => '3 min',
      _ => 'few min',
    };

    return InkWell(
      onTap: () => _joinExerciseAndOpen(activityId, exerciseType),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cs.outline.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_cs.primary, _cs.secondary]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                exerciseType == 'breathing'
                    ? Icons.air_rounded
                    : exerciseType == 'yoga'
                        ? Icons.self_improvement_rounded
                        : Icons.play_circle_outline_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _cs.onSurface)),
                const SizedBox(height: 2),
                Text(
                  me ? 'You invited ${_partnerName ?? 'friend'} • $durLabel'
                     : '${_partnerName ?? 'Friend'} invited you • $durLabel',
                  style: TextStyle(fontSize: 12, color: _cs.onSurface.withOpacity(0.6)),
                ),
              ]),
            ),
            Icon(Icons.arrow_forward_rounded, color: _cs.onSurface.withOpacity(0.35), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: _isDark ? Colors.black.withOpacity(0.15) : Colors.white.withOpacity(0.9),
        border: Border(top: BorderSide(color: _cs.outline.withOpacity(0.15))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              tooltip: 'Invite to exercise',
              icon: const Icon(Icons.add_reaction_rounded),
              onPressed: _showExercisePicker,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: _textCtrl,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendTextMessage(),
                decoration: InputDecoration(
                  hintText: 'Message',
                  filled: true,
                  fillColor: _isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _sending ? null : _sendTextMessage,
              child: _sending
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send_rounded, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
