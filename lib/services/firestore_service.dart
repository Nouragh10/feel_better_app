// PATH: lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Firestore paths used by the app:
/// - users/{uid}
/// - friendships/{uid}/friends/{friendUid}
/// - entries/{uid}/{yyyy-MM}/{entryId}
/// - entries_public/{entryId}
/// - pings/{recipientUid}/inbox/{pingId}
/// - providers/{providerUid}/clients/{clientUid}
/// - streak_pairs/{pairId}
///   - sessions/{yyyy-MM-dd}
class FirestoreService {
  FirestoreService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  // ----------------------------- USERS -----------------------------

  Future<void> upsertUser({
    required String uid,
    required String displayName,
    required String username,
    String? photoUrl,
    List<String> providerIds = const [],
  }) async {
    final lower = username.trim().toLowerCase();
    await _db.collection('users').doc(uid).set({
      'displayName': displayName,
      'username': username,
      'usernameLower': lower,
      'photoUrl': photoUrl,
      'providerIds': providerIds,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getUser(String uid) {
    return _db.collection('users').doc(uid).get();
  }

  /// Look up uid by username (case-insensitive).
  Future<String?> getUidByUsername(String username) async {
    final lower = username.trim().toLowerCase();
    // Prefer usernameLower if present
    var q = await _db
        .collection('users')
        .where('usernameLower', isEqualTo: lower)
        .limit(1)
        .get();
    if (q.docs.isNotEmpty) return q.docs.first.id;

    // Fallback for older profiles
    q = await _db
        .collection('users')
        .where('username', isEqualTo: username.trim())
        .limit(1)
        .get();
    if (q.docs.isNotEmpty) return q.docs.first.id;

    return null;
  }

  // -------------------------- FRIENDSHIPS --------------------------

  /// Create a symmetric friend request:
  /// - requester sees `pending`
  /// - recipient sees `incoming`
  Future<void> sendFriendRequest({
    required String fromUid,
    required String toUid,
  }) async {
    final now = FieldValue.serverTimestamp();
    final a = _db
        .collection('friendships')
        .doc(fromUid)
        .collection('friends')
        .doc(toUid);
    final b = _db
        .collection('friendships')
        .doc(toUid)
        .collection('friends')
        .doc(fromUid);

    final batch = _db.batch();
    batch.set(a, {'status': 'pending', 'updatedAt': now, 'createdAt': now},
        SetOptions(merge: true));
    batch.set(b, {'status': 'incoming', 'updatedAt': now, 'createdAt': now},
        SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> acceptFriendship({
    required String uid,
    required String friendUid,
  }) async {
    final batch = _db.batch();
    final now = FieldValue.serverTimestamp();
    final a = _db
        .collection('friendships')
        .doc(uid)
        .collection('friends')
        .doc(friendUid);
    final b = _db
        .collection('friendships')
        .doc(friendUid)
        .collection('friends')
        .doc(uid);
    batch.set(a, {'status': 'accepted', 'updatedAt': now},
        SetOptions(merge: true));
    batch.set(b, {'status': 'accepted', 'updatedAt': now},
        SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> removeFriend({
    required String uid,
    required String friendUid,
  }) async {
    final batch = _db.batch();
    final a = _db
        .collection('friendships')
        .doc(uid)
        .collection('friends')
        .doc(friendUid);
    final b = _db
        .collection('friendships')
        .doc(friendUid)
        .collection('friends')
        .doc(uid);
    batch.delete(a);
    batch.delete(b);
    await batch.commit();
  }

  /// Stream all friend docs for a user (incoming/pending/accepted), newest first.
  Stream<QuerySnapshot<Map<String, dynamic>>> friendshipsStream(String uid) {
    return _db
        .collection('friendships')
        .doc(uid)
        .collection('friends')
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  Future<List<String>> listFriendIds(String uid) async {
    final q = await _db
        .collection('friendships')
        .doc(uid)
        .collection('friends')
        .where('status', isEqualTo: 'accepted')
        .get();
    return q.docs.map((d) => d.id).toList();
  }

  // ----------------------------- ENTRIES ---------------------------

  Future<String> addEntry({
    required String uid,
    required String mood,
    required String nearby,
    required String suggestion,
    required bool shareWithFriends,
    required bool shareWithProviders,
    String? publicSummary,
    DateTime? createdAtLocal,
  }) async {
    final month = DateFormat('yyyy-MM').format(DateTime.now());
    final ref =
        _db.collection('entries').doc(uid).collection(month).doc(); // auto id
    await ref.set({
      'entryId': ref.id,
      'authorId': uid,
      'mood': mood,
      'nearby': nearby,
      'suggestion': suggestion,
      'publicSummary': publicSummary ?? 'felt $mood • suggestion: $suggestion',
      'shareWithFriends': shareWithFriends,
      'shareWithProviders': shareWithProviders,
      'createdAt': FieldValue.serverTimestamp(),
      if (createdAtLocal != null)
        'createdAtLocal': createdAtLocal.toIso8601String(),
    });
    return ref.id;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> entriesForRange({
    required String uid,
    required DateTime startInclusive,
    required DateTime endExclusive,
  }) async {
    final months = _monthBucketsBetween(startInclusive, endExclusive);
    final results = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final m in months) {
      final snap = await _db
          .collection('entries')
          .doc(uid)
          .collection(m)
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startInclusive))
          .where('createdAt',
              isLessThan: Timestamp.fromDate(endExclusive))
          .orderBy('createdAt', descending: true)
          .get();
      results.addAll(snap.docs);
    }
    return results;
  }

  // --------------------------- PUBLIC FEED -------------------------

  Future<void> mirrorPublicEntry({
    required String entryId,
    required String authorId,
    required String publicSummary,
    Timestamp? createdAt,
  }) async {
    await _db.collection('entries_public').doc(entryId).set({
      'entryId': entryId,
      'authorId': authorId,
      'publicSummary': publicSummary,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> publicFeedForFriends({
    required List<String> friendIds,
    int limit = 50,
  }) {
    if (friendIds.isEmpty) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }
    final ids = friendIds.length > 10 ? friendIds.sublist(0, 10) : friendIds;

    // Avoid orderBy to prevent composite index errors for now.
    return _db
        .collection('entries_public')
        .where('authorId', whereIn: ids)
        .limit(limit)
        .snapshots();
  }

  // ------------------------------ PINGS ----------------------------

  Future<void> sendPing({
    required String fromUid,
    required String toUid,
    String? note,
  }) async {
    final inbox =
        _db.collection('pings').doc(toUid).collection('inbox').doc();
    await inbox.set({
      'pingId': inbox.id,
      'type': 'ping',
      'fromUid': fromUid,
      'toUid': toUid,
      'note': note,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> pingsInboxStream(String uid) {
    return _db
        .collection('pings')
        .doc(uid)
        .collection('inbox')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots();
  }

  Future<void> markPingRead({
    required String recipientUid,
    required String pingId,
  }) async {
    await _db
        .collection('pings')
        .doc(recipientUid)
        .collection('inbox')
        .doc(pingId)
        .set({'read': true}, SetOptions(merge: true));
  }

  // --------------------------- PROVIDERS ---------------------------

  Future<void> connectProvider({
    required String userUid,
    required String providerUid,
  }) async {
    final now = FieldValue.serverTimestamp();
    final userDoc = _db.collection('users').doc(userUid);
    final providerClientDoc = _db
        .collection('providers')
        .doc(providerUid)
        .collection('clients')
        .doc(userUid);

    final batch = _db.batch();
    batch.set(providerClientDoc, {'consent': true, 'since': now},
        SetOptions(merge: true));
    batch.set(userDoc, {
      'providerIds': FieldValue.arrayUnion([providerUid]),
      'updatedAt': now,
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> revokeProvider({
    required String userUid,
    required String providerUid,
  }) async {
    final userDoc = _db.collection('users').doc(userUid);
    final providerClientDoc = _db
        .collection('providers')
        .doc(providerUid)
        .collection('clients')
        .doc(userUid);

    final batch = _db.batch();
    batch.delete(providerClientDoc);
    batch.set(userDoc, {
      'providerIds': FieldValue.arrayRemove([providerUid]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> providerClientEntries({
    required String clientUid,
    required DateTime startInclusive,
    required DateTime endExclusive,
  }) {
    return entriesForRange(
      uid: clientUid,
      startInclusive: startInclusive,
      endExclusive: endExclusive,
    );
  }

  // ------------------------------ STREAKS --------------------------

  String _pairId(String a, String b) {
    final x = [a, b]..sort();
    return '${x[0]}__${x[1]}';
  }

  String _dayKeyWithOffset(Duration offset) {
    final now = DateTime.now().toUtc().add(offset);
    return DateFormat('yyyy-MM-dd').format(now);
  }

  DocumentReference<Map<String, dynamic>> _pairRef(String uidA, String uidB) {
    final id = _pairId(uidA, uidB);
    return _db.collection('streak_pairs').doc(id);
  }

  /// Ensure a pair doc exists.
  Future<void> ensureStreakPair(String uidA, String uidB) async {
    final ref = _pairRef(uidA, uidB);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'pairId': ref.id,
        'participants': [uidA, uidB]..sort(),
        'currentStreak': 0,
        'longestStreak': 0,
        'lastDayKey': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Create today’s session (or return existing), then ping friend with a streak_invite.
  Future<void> startStreakSessionAndInvite({
    required String fromUid,
    required String toUid,
    String? note,
    int? tzOffsetMinutes,
  }) async {
    await ensureStreakPair(fromUid, toUid);
    final pairRef = _pairRef(fromUid, toUid);

    final offsetMinutes =
        tzOffsetMinutes ?? DateTime.now().timeZoneOffset.inMinutes;
    final dayKey = _dayKeyWithOffset(Duration(minutes: offsetMinutes));

    final sessionRef = pairRef.collection('sessions').doc(dayKey);
    final sessionSnap = await sessionRef.get();
    if (!sessionSnap.exists) {
      await sessionRef.set({
        'dayKey': dayKey,
        'tzOffsetMinutes': offsetMinutes,
        'startedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().toUtc().add(const Duration(hours: 26))),
        'moods': {},
        'items': {},
        'suggestions': {},
        'completed': {},
      });
    }

    // Send invite (stored in pings inbox)
    final inbox = _db.collection('pings').doc(toUid).collection('inbox').doc();
    await inbox.set({
      'pingId': inbox.id,
      'type': 'streak_invite',
      'pairId': pairRef.id,
      'dayKey': dayKey,
      'fromUid': fromUid,
      'toUid': toUid,
      'note': note,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Submit your check-in for a specific day (defaults to local day if not provided).
  /// FIX: All reads happen before writes (Firestore requirement), then we update.
  Future<void> submitStreakCheckin({
    required String uid,
    required String friendUid,
    required String mood,
    required List<String> items,
    required String suggestion,
    String? dayKeyOverride,
  }) async {
    final pairRef = _pairRef(uid, friendUid);

    final offsetMinutes = DateTime.now().timeZoneOffset.inMinutes;
    final dayKey = dayKeyOverride ?? _dayKeyWithOffset(Duration(minutes: offsetMinutes));
    final sessionRef = pairRef.collection('sessions').doc(dayKey);

    await _db.runTransaction((tx) async {
      // ----- READS FIRST -----
      final pairSnap = await tx.get(pairRef);
      final sessionSnap = await tx.get(sessionRef);

      // Prepare session state (existing or new)
      final Map<String, dynamic> baseSession = sessionSnap.data() ?? {};
      final moods = Map<String, dynamic>.from(baseSession['moods'] ?? {});
      final itemsMap = Map<String, dynamic>.from(baseSession['items'] ?? {});
      final suggestions = Map<String, dynamic>.from(baseSession['suggestions'] ?? {});
      final completed = Map<String, dynamic>.from(baseSession['completed'] ?? {});

      // Apply this user's completion
      moods[uid] = mood;
      itemsMap[uid] = items;
      suggestions[uid] = suggestion;
      completed[uid] = true;

      // ----- WRITES -----
      // Upsert session
      tx.set(sessionRef, {
        'dayKey': dayKey,
        'tzOffsetMinutes': offsetMinutes,
        'startedAt': baseSession['startedAt'] ?? FieldValue.serverTimestamp(),
        'expiresAt': baseSession['expiresAt'] ??
            Timestamp.fromDate(DateTime.now().toUtc().add(const Duration(hours: 26))),
        'moods': moods,
        'items': itemsMap,
        'suggestions': suggestions,
        'completed': completed,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // If both completed, update streak counters atomically on the pair doc.
      final bothDone = (completed[uid] == true) && (completed[friendUid] == true);
      if (bothDone) {
        final pd = pairSnap.data() ?? {};
        final lastDayKey = pd['lastDayKey'] as String?;
        final currentStreak = (pd['currentStreak'] as int?) ?? 0;
        final longestStreak = (pd['longestStreak'] as int?) ?? 0;

        int nextStreak;
        if (lastDayKey == null) {
          nextStreak = 1;
        } else if (lastDayKey == dayKey) {
          nextStreak = currentStreak; // already counted today
        } else {
          final prev = DateTime.parse(lastDayKey);
          final cur = DateTime.parse(dayKey);
          final isConsecutive = cur.difference(prev).inDays == 1;
          nextStreak = isConsecutive ? currentStreak + 1 : 1;
        }

        tx.set(pairRef, {
          'lastDayKey': dayKey,
          'currentStreak': nextStreak,
          'longestStreak': nextStreak > longestStreak ? nextStreak : longestStreak,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    });
  }

  /// Stream the pair’s streak counters (for the chip UI).
  Stream<DocumentSnapshot<Map<String, dynamic>>> streakPairStream(
    String uidA,
    String uidB,
  ) {
    final id = _pairId(uidA, uidB);
    return _db.collection('streak_pairs').doc(id).snapshots();
  }

  // ----------------------------- HELPERS ---------------------------

  List<String> _monthBucketsBetween(DateTime start, DateTime endExclusive) {
    var s = DateTime(start.year, start.month);
    final end = DateTime(endExclusive.year, endExclusive.month);
    final res = <String>[];
    while (!DateUtils.isSameMonth(s, end)) {
      res.add(DateFormat('yyyy-MM').format(s));
      s = DateTime(s.year, s.month + 1);
    }
    res.add(DateFormat('yyyy-MM').format(end));
    return res;
  }
}

class DateUtils {
  static bool isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }
}
