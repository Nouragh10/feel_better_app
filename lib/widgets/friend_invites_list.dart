// PATH: lib/widgets/friend_invites_list.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class FriendInvitesList extends StatefulWidget {
  const FriendInvitesList({
    super.key,
    required this.currentUid,
  });

  final String currentUid;

  @override
  State<FriendInvitesList> createState() => _FriendInvitesListState();
}

class _FriendInvitesListState extends State<FriendInvitesList> {
  final _fs = FirestoreService();
  final _db = FirebaseFirestore.instance;

  // simple in-memory cache uid -> user map
  final Map<String, Map<String, dynamic>?> _userCache = {};

  Future<Map<String, dynamic>?> _getUser(String uid) async {
    if (_userCache.containsKey(uid)) return _userCache[uid];
    final snap = await _fs.getUser(uid);
    final data = snap.data();
    _userCache[uid] = data;
    return data;
  }

  @override
  Widget build(BuildContext context) {
    final title = Theme.of(context).textTheme.titleMedium;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db
          .collection('friendships')
          .doc(widget.currentUid)
          .collection('friends')
          .orderBy('updatedAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(minHeight: 2),
          );
        }
        final docs = snap.data?.docs ?? [];

        final incoming = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        final sentPending = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        for (final d in docs) {
          final status = (d.data()['status'] as String?) ?? 'pending';
          if (status == 'incoming') {
            incoming.add(d);
          } else if (status == 'pending') {
            sentPending.add(d);
          }
        }

        if (incoming.isEmpty && sentPending.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (incoming.isNotEmpty) ...[
              Row(
                children: [
                  Text('Incoming requests', style: title),
                  const SizedBox(width: 6),
                  const Icon(Icons.mail_outline, size: 18),
                ],
              ),
              const SizedBox(height: 8),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: incoming.length,
                separatorBuilder: (_, __) => const Divider(height: 8),
                itemBuilder: (context, i) {
                  final d = incoming[i];
                  final friendUid = d.id;

                  return FutureBuilder<Map<String, dynamic>?>(
                    future: _getUser(friendUid),
                    builder: (context, userSnap) {
                      final u = userSnap.data;
                      final name = (u?['displayName'] as String?) ?? 'Unknown';
                      final uname = (u?['username'] as String?) ?? 'unknown';

                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                          ),
                        ),
                        title: Text(name),
                        subtitle: Text('@$uname • incoming'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () =>
                                  _fs.acceptFriendship(uid: widget.currentUid, friendUid: friendUid),
                              child: const Text('Accept'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  _fs.removeFriend(uid: widget.currentUid, friendUid: friendUid),
                              child: const Text('Decline'),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
            if (sentPending.isNotEmpty) ...[
              Row(
                children: [
                  Text('Sent requests', style: title),
                  const SizedBox(width: 6),
                  const Icon(Icons.outbox_rounded, size: 18),
                ],
              ),
              const SizedBox(height: 8),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sentPending.length,
                separatorBuilder: (_, __) => const Divider(height: 8),
                itemBuilder: (context, i) {
                  final d = sentPending[i];
                  final friendUid = d.id;

                  return FutureBuilder<Map<String, dynamic>?>(
                    future: _getUser(friendUid),
                    builder: (context, userSnap) {
                      final u = userSnap.data;
                      final name = (u?['displayName'] as String?) ?? 'Unknown';
                      final uname = (u?['username'] as String?) ?? 'unknown';

                      return ListTile(
                        leading: const Icon(Icons.hourglass_top_rounded),
                        title: Text(name),
                        subtitle: Text('@$uname • pending'),
                        trailing: TextButton(
                          onPressed: () =>
                              _fs.removeFriend(uid: widget.currentUid, friendUid: friendUid),
                          child: const Text('Cancel'),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ],
        );
      },
    );
  }
}
