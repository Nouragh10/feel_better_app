// PATH: lib/services/challenge_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

/// One of the built-in 7-day challenge templates.
class ChallengeTemplate {
  final String id;
  final String emoji;
  final String title;
  final String description;
  final List<String> dailyTasks; // one per day, 7 total

  const ChallengeTemplate({
    required this.id,
    required this.emoji,
    required this.title,
    required this.description,
    required this.dailyTasks,
  });
}

/// A live challenge between two friends stored in Firestore.
class SharedChallenge {
  final String id;
  final String templateId;
  final String initiatorUid;
  final String partnerUid;
  final DateTime startDate;
  final String status; // 'pending' | 'active' | 'completed' | 'declined'

  // day index (0–6) → uid → bool
  final Map<int, Map<String, bool>> completions;

  const SharedChallenge({
    required this.id,
    required this.templateId,
    required this.initiatorUid,
    required this.partnerUid,
    required this.startDate,
    required this.status,
    required this.completions,
  });

  factory SharedChallenge.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    final rawComp =
        (d['completions'] as Map<String, dynamic>?) ?? {};
    final completions = <int, Map<String, bool>>{};
    rawComp.forEach((dayStr, uids) {
      final dayIdx = int.tryParse(dayStr) ?? 0;
      completions[dayIdx] = (uids as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v as bool));
    });

    return SharedChallenge(
      id: doc.id,
      templateId: d['templateId'] as String,
      initiatorUid: d['initiatorUid'] as String,
      partnerUid: d['partnerUid'] as String,
      startDate: (d['startDate'] as Timestamp).toDate(),
      status: d['status'] as String? ?? 'pending',
      completions: completions,
    );
  }

  /// Which day of the challenge are we on? (0-based, clamped 0–6)
  int get currentDay {
    final diff = DateTime.now().difference(startDate).inDays;
    return diff.clamp(0, 6);
  }

  bool isCompleted(int day, String uid) =>
      completions[day]?[uid] == true;

  bool bothCompleted(int day) {
    final m = completions[day];
    if (m == null) return false;
    return m[initiatorUid] == true && m[partnerUid] == true;
  }

  /// How many days have both partners completed?
  int get sharedDaysCompleted {
    int count = 0;
    for (int d = 0; d <= 6; d++) {
      if (bothCompleted(d)) count++;
    }
    return count;
  }

  bool get isFinished =>
      status == 'completed' ||
      (status == 'active' &&
          DateTime.now().difference(startDate).inDays >= 7);
}

// ---------------------------------------------------------------------------
// Built-in challenge templates
// ---------------------------------------------------------------------------

const List<ChallengeTemplate> kChallengeTemplates = [
  ChallengeTemplate(
    id: 'drink_water',
    emoji: '💧',
    title: 'Hydration Week',
    description: 'Drink 8 glasses of water every day for 7 days.',
    dailyTasks: [
      'Start your morning with a full glass of water before coffee or tea.',
      'Set a reminder every 2 hours and drink a glass each time.',
      'Replace one sugary drink today with water.',
      'Drink a glass of water before each meal.',
      'End your day with a glass of water and notice how you feel.',
      'Track every glass today — aim for 8.',
      'Final day: reflect on how hydration affected your mood this week.',
    ],
  ),
  ChallengeTemplate(
    id: 'daily_stretch',
    emoji: '🧘',
    title: 'Stretch Together',
    description: 'Do a 5-minute stretch every day for 7 days.',
    dailyTasks: [
      'Morning neck and shoulder rolls — 2 minutes each side.',
      'Stand up and touch your toes 10 times, breathing slowly.',
      'Cat-cow stretch on the floor — 10 reps.',
      'Side bends — 30 seconds each side, twice.',
      'Hip flexor stretch — hold 30 seconds each leg.',
      'Full body stretch routine — 5 minutes, no rush.',
      'Celebrate! Do your favorite stretch and hold for a full minute.',
    ],
  ),
  ChallengeTemplate(
    id: 'log_mood',
    emoji: '📓',
    title: 'Mood Check-In',
    description: 'Log your mood every day and share a word with your friend.',
    dailyTasks: [
      'Log your mood this morning — just one word.',
      'Log your mood at midday. Any different from this morning?',
      'Before bed, log your mood and note one thing that shaped it.',
      'Log your mood and write one sentence about your day.',
      'Log your mood and share what helped it (or didn\'t).',
      'Log your mood twice today — morning and evening.',
      'Final log: how has your mood shifted over the week?',
    ],
  ),
  ChallengeTemplate(
    id: 'gratitude',
    emoji: '🌟',
    title: 'Gratitude Week',
    description: 'Write one thing you\'re grateful for every day.',
    dailyTasks: [
      'Write one small thing you\'re grateful for today.',
      'Write one thing about yourself you\'re grateful for.',
      'Write one thing about a friend you\'re grateful for.',
      'Write one thing you\'re grateful for that you usually take for granted.',
      'Write one thing from nature you\'re grateful for.',
      'Write one memory you\'re grateful for.',
      'Write one thing you\'re grateful for about this week.',
    ],
  ),
  ChallengeTemplate(
    id: 'no_phone_morning',
    emoji: '📵',
    title: 'Phone-Free Mornings',
    description: 'Keep your phone away for the first 30 minutes after waking.',
    dailyTasks: [
      'Wake up and leave your phone on the nightstand for 30 minutes.',
      'Use those 30 minutes to stretch or make a slow breakfast.',
      'Write down one intention for the day before checking your phone.',
      'Notice how you feel after 30 phone-free minutes. Calmer?',
      'Try extending to 45 minutes today.',
      'Use the time to sit quietly and breathe for 5 minutes.',
      'Final day: reflect on how mornings felt differently this week.',
    ],
  ),
  ChallengeTemplate(
    id: 'fresh_air',
    emoji: '🌿',
    title: 'Daily Fresh Air',
    description: 'Step outside for at least 10 minutes every day.',
    dailyTasks: [
      'Step outside for 10 minutes and notice 3 things in nature.',
      'Take a short walk without your phone or headphones.',
      'Find a spot to sit outside for 10 minutes and just breathe.',
      'Walk a different route today and notice something new.',
      'Go outside right after waking — even just to the doorstep.',
      'Take someone (or a call) outside with you today.',
      'Final day: spend 15 minutes outside reflecting on the week.',
    ],
  ),
];

ChallengeTemplate? templateById(String id) {
  try {
    return kChallengeTemplates.firstWhere((t) => t.id == id);
  } catch (_) {
    return null;
  }
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

class ChallengeService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('shared_challenges');

  // ---- Send a challenge invite ----

  Future<String> sendChallenge({
    required String fromUid,
    required String toUid,
    required String templateId,
  }) async {
    final ref = _col.doc();
    await ref.set({
      'templateId': templateId,
      'initiatorUid': fromUid,
      'partnerUid': toUid,
      'startDate': null, // set when accepted
      'status': 'pending',
      'completions': {},
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  // ---- Accept / decline ----

  Future<void> acceptChallenge(String challengeId) async {
    await _col.doc(challengeId).update({
      'status': 'active',
      'startDate': Timestamp.fromDate(
        DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
        ),
      ),
    });
  }

  Future<void> declineChallenge(String challengeId) async {
    await _col.doc(challengeId).update({'status': 'declined'});
  }

  // ---- Mark a day complete ----

  Future<void> markDayComplete({
    required String challengeId,
    required int dayIndex,
    required String uid,
  }) async {
    final ref = _col.doc(challengeId);
    await ref.update({
      'completions.$dayIndex.$uid': true,
    });

    // Auto-complete challenge after day 6
    final snap = await ref.get();
    if (snap.exists) {
      final challenge = SharedChallenge.fromDoc(snap);
      if (challenge.currentDay >= 6 &&
          challenge.completions[6]?[uid] == true) {
        // Check if partner also done on day 6
        final partnerId = uid == challenge.initiatorUid
            ? challenge.partnerUid
            : challenge.initiatorUid;
        if (challenge.completions[6]?[partnerId] == true) {
          await ref.update({'status': 'completed'});
        }
      }
    }
  }

  // ---- Streams ----

  /// All active/pending challenges where uid is a participant.
  Stream<List<SharedChallenge>> activeChallengesStream(String uid) {
    return _col
        .where(Filter.or(
          Filter('initiatorUid', isEqualTo: uid),
          Filter('partnerUid', isEqualTo: uid),
        ))
        .where('status', whereIn: ['pending', 'active'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => SharedChallenge.fromDoc(d))
            .toList());
  }

  /// Stream a single challenge.
  Stream<SharedChallenge?> challengeStream(String challengeId) {
    return _col.doc(challengeId).snapshots().map((s) =>
        s.exists ? SharedChallenge.fromDoc(s) : null);
  }

  /// Past completed challenges for a user.
  Future<List<SharedChallenge>> completedChallenges(String uid) async {
    final snap = await _col
        .where(Filter.or(
          Filter('initiatorUid', isEqualTo: uid),
          Filter('partnerUid', isEqualTo: uid),
        ))
        .where('status', isEqualTo: 'completed')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();
    return snap.docs.map((d) => SharedChallenge.fromDoc(d)).toList();
  }

  /// Pending challenges sent TO this user (they need to respond).
  Stream<List<SharedChallenge>> incomingInvitesStream(String uid) {
    return _col
        .where('partnerUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) => s.docs
            .map((d) => SharedChallenge.fromDoc(d))
            .toList());
  }
}