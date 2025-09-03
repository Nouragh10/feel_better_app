// PATH: lib/widgets/friends_shares_feed.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';

/// Shows a live feed of your friends' public shares.
/// Each item reads like: "<friendName> felt ... and was recommended: ...".
class FriendsSharesFeed extends StatefulWidget {
  const FriendsSharesFeed({
    super.key,
    required this.currentUid,
    this.emptyHint = 'No shares yet.',
    this.maxFriendsPerQuery = 10,
  });

  /// The signed-in (or local-fallback) user id.
  final String currentUid;

  /// Text to show when there are no items.
  final String emptyHint;

  /// Firestore `whereIn` supports up to 10 values; keep that default.
  final int maxFriendsPerQuery;

  @override
  State<FriendsSharesFeed> createState() => _FriendsSharesFeedState();
}

class _FriendsSharesFeedState extends State<FriendsSharesFeed> {
  final _fs = FirestoreService();
  final _db = FirebaseFirestore.instance;

  // Cache friend uid -> display name / username for quick rendering
  final Map<String, String> _nameCache = {};

  Future<List<String>> _loadFriendIds() async {
    final ids = await _fs.listFriendIds(widget.currentUid);
    if (ids.isEmpty) return <String>[];
    // Only first N are used per query (whereIn limit). Keep it simple for now.
    return ids.length > widget.maxFriendsPerQuery
        ? ids.sublist(0, widget.maxFriendsPerQuery)
        : ids;
  }

  Future<void> _warmNameCache(List<String> friendIds) async {
    final missing = friendIds.where((id) => !_nameCache.containsKey(id)).toList();
    if (missing.isEmpty) return;

    // Batch fetch (<= 10) user docs by id
    final snap = await _db
        .collection('users')
        .where(FieldPath.documentId, whereIn: missing)
        .get();

    for (final d in snap.docs) {
      final data = d.data();
      final display = (data['displayName'] as String?)?.trim();
      final username = (data['username'] as String?)?.trim();
      _nameCache[d.id] = display?.isNotEmpty == true
          ? display!
          : (username?.isNotEmpty == true ? username! : 'Someone');
    }
  }

  String _nameFor(String uid) => _nameCache[uid] ?? 'Someone';

  String _relativeTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Text("Friends’ shares", style: titleStyle),
            const SizedBox(width: 6),
            const Icon(Icons.rss_feed_rounded, size: 18),
          ],
        ),
        const SizedBox(height: 10),

        FutureBuilder<List<String>>(
          future: _loadFriendIds(),
          builder: (context, snapIds) {
            if (snapIds.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(minHeight: 2),
              );
            }
            if (snapIds.hasError) {
              return const Text('Couldn’t load friends.');
            }
            final ids = snapIds.data ?? const <String>[];
            if (ids.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(widget.emptyHint),
              );
            }

            // Prepare names once before streaming the feed
            return FutureBuilder<void>(
              future: _warmNameCache(ids),
              builder: (context, snapWarm) {
                if (snapWarm.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: LinearProgressIndicator(minHeight: 2),
                  );
                }

                // DIRECT query without orderBy (avoids index); we'll sort client-side
                final stream = _db
                    .collection('entries_public')
                    .where('authorId', whereIn: ids)
                    .limit(50)
                    .snapshots();

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: stream,
                  builder: (context, feedSnap) {
                    if (feedSnap.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: LinearProgressIndicator(minHeight: 2),
                      );
                    }
                    if (feedSnap.hasError) {
                      return const Text('Couldn’t load shares.');
                    }

                    // Sort newest-first on the client.
                    final raw = feedSnap.data?.docs ?? const [];
                    final docs = [...raw]..sort((a, b) {
                      final ta = (a.data()['createdAt'] as Timestamp?);
                      final tb = (b.data()['createdAt'] as Timestamp?);
                      final da = ta?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                      final db = tb?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                      return db.compareTo(da);
                    });

                    if (docs.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(widget.emptyHint),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const Divider(height: 12),
                      itemBuilder: (context, i) {
                        final d = docs[i].data();
                        final authorId = (d['authorId'] as String?) ?? '';
                        final summary = (d['publicSummary'] as String?) ?? '';
                        final createdAt = d['createdAt'] as Timestamp?;
                        final name = _nameFor(authorId);

                        // Display: "Noura felt ... and was recommended: ..."
                        final text = '$name $summary';

                        return ListTile(
                          dense: false,
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 16,
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          title: Text(text),
                          subtitle: Text(_relativeTime(createdAt)),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }
}
