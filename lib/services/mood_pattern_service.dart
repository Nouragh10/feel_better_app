// PATH: lib/services/mood_pattern_service.dart
//
// Tracks mood history, detects patterns, and provides personalization context
// for the OpenAI prompt. Works entirely on top of existing Firestore collections.
//
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// A lightweight summary of the user's recent mood history.
class MoodInsight {
  /// e.g. "anxious" — the most common mood in the last 14 days
  final String? dominantMood;

  /// e.g. "evening" — the time-of-day bucket when the user most often checks in
  final String? peakCheckInTime;

  /// The last 5 distinct moods (newest first), used to avoid repetition
  final List<String> recentMoods;

  /// Suggestion texts seen in the last 7 days — used to avoid repeating them
  final List<String> recentSuggestions;

  /// Whether the user's mood trend is improving, declining, or mixed
  final String moodTrend; // 'improving' | 'declining' | 'mixed' | 'unknown'

  /// Raw frequency map: mood -> count (last 30 days)
  final Map<String, int> moodFrequency;

  const MoodInsight({
    this.dominantMood,
    this.peakCheckInTime,
    this.recentMoods = const [],
    this.recentSuggestions = const [],
    this.moodTrend = 'unknown',
    this.moodFrequency = const {},
  });

  bool get hasData => dominantMood != null || recentMoods.isNotEmpty;

  /// Build a compact string to inject into the OpenAI system prompt.
  String toPromptContext() {
    if (!hasData) return '';

    final parts = <String>[];

    if (dominantMood != null) {
      parts.add('User most often feels "$dominantMood" lately');
    }
    if (peakCheckInTime != null) {
      parts.add('usually checks in during the $peakCheckInTime');
    }
    if (moodTrend != 'unknown') {
      parts.add('mood trend is $moodTrend');
    }
    if (recentMoods.length > 1) {
      parts.add('recent moods: ${recentMoods.take(4).join(', ')}');
    }

    return parts.isEmpty ? '' : 'User pattern context: ${parts.join('; ')}.';
  }

  /// Returns suggestions to explicitly exclude from the next response.
  String toExclusionHint() {
    if (recentSuggestions.isEmpty) return '';
    final excerpts = recentSuggestions
        .take(5)
        .map((s) => '"${s.length > 60 ? s.substring(0, 60) : s}…"')
        .join(', ');
    return 'Do NOT repeat or closely paraphrase these recent suggestions: $excerpts';
  }
}

class MoodPatternService {
  MoodPatternService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Analyse the user's last 30 days of entries and return a [MoodInsight].
  /// Safe to call on every suggestion request — Firestore reads are cheap for
  /// the small number of docs involved.
  Future<MoodInsight> getInsight(String uid) async {
    try {
      final entries = await _fetchRecentEntries(uid, days: 30);
      if (entries.isEmpty) return const MoodInsight();

      final moodFreq = _buildMoodFrequency(entries);
      final dominantMood = _dominantMood(moodFreq);
      final peakTime = _peakCheckInTime(entries);
      final recentMoods = _recentMoods(entries, limit: 6);
      final trend = _moodTrend(entries);
      final recentSuggestions = _recentSuggestions(entries, days: 7);

      return MoodInsight(
        dominantMood: dominantMood,
        peakCheckInTime: peakTime,
        recentMoods: recentMoods,
        recentSuggestions: recentSuggestions,
        moodTrend: trend,
        moodFrequency: moodFreq,
      );
    } catch (_) {
      return const MoodInsight();
    }
  }

  /// Returns the best content type for the current mood + insight combo.
  /// This replaces the simplistic `_inferContentType` in OpenAIService.
  static String recommendContentType({
    required String mood,
    required MoodInsight insight,
    required List<String> items,
    String? hourBucket,
  }) {
    final m = mood.toLowerCase();
    final hour = hourBucket ?? _currentHourBucket();

    final hasDevice = items.any((i) {
      final t = i.toLowerCase();
      return t.contains('phone') ||
          t.contains('laptop') ||
          t.contains('tablet') ||
          t.contains('headphone') ||
          t.contains('earbud');
    });

    // Score each content type
    final scores = <String, double>{
      'song': 0,
      'podcast': 0,
      'video': 0,
      'exercise': 0,
    };

    // --- Mood signals ---
    if (_hasAny(m, ['anx', 'panic', 'tense', 'nervous'])) {
      scores['video'] = scores['video']! + 2.5; // breathing/guided videos best
      scores['exercise'] = scores['exercise']! + 2.0;
      scores['song'] = scores['song']! + 1.5;
    }
    if (_hasAny(m, ['sad', 'low', 'down', 'blue', 'depress'])) {
      scores['song'] = scores['song']! + 2.5;
      scores['video'] = scores['video']! + 1.5;
      scores['podcast'] = scores['podcast']! + 1.0;
    }
    if (_hasAny(m, ['overwhelm', 'stress', 'busy', 'scatter'])) {
      scores['exercise'] = scores['exercise']! + 2.5;
      scores['song'] = scores['song']! + 1.5;
      scores['video'] = scores['video']! + 1.0;
    }
    if (_hasAny(m, ['angry', 'frustrat', 'irritat', 'mad'])) {
      scores['exercise'] = scores['exercise']! + 2.5;
      scores['song'] = scores['song']! + 2.0;
    }
    if (_hasAny(m, ['exhaust', 'tired', 'drained', 'sleepy'])) {
      scores['video'] = scores['video']! + 2.0;
      scores['song'] = scores['song']! + 1.5;
      scores['exercise'] = scores['exercise']! + 0.5; // gentle only
    }
    if (_hasAny(m, ['bored', 'stuck', 'unmotivat'])) {
      scores['podcast'] = scores['podcast']! + 2.0;
      scores['song'] = scores['song']! + 1.5;
      scores['video'] = scores['video']! + 1.5;
    }

    // --- Device availability ---
    if (!hasDevice) {
      scores['song'] = scores['song']! * 0.3;
      scores['podcast'] = scores['podcast']! * 0.3;
      scores['video'] = scores['video']! * 0.3;
      scores['exercise'] = scores['exercise']! + 2.0;
    }

    // --- Time of day ---
    if (hour == 'late_night') {
      scores['exercise'] = scores['exercise']! * 0.5;
      scores['video'] = scores['video']! + 0.5; // calming wind-down
      scores['song'] = scores['song']! + 0.5;
    }
    if (hour == 'morning') {
      scores['exercise'] = scores['exercise']! + 0.5;
      scores['podcast'] = scores['podcast']! + 0.5;
    }

    // --- Mood pattern learning: avoid repeating same type as dominant ---
    if (insight.dominantMood != null) {
      final dom = insight.dominantMood!.toLowerCase();
      // If their dominant mood is one we'd normally suggest song for,
      // and they've been doing that a lot, boost variety.
      if (_hasAny(dom, ['sad', 'low']) && insight.moodFrequency[dom] != null) {
        final freq = insight.moodFrequency[dom]!;
        if (freq > 5) {
          // They've been sad a lot — try mixing in exercises and videos
          scores['exercise'] = scores['exercise']! + 1.0;
          scores['video'] = scores['video']! + 0.5;
        }
      }
    }

    // --- Trend signals ---
    if (insight.moodTrend == 'declining') {
      // Boost grounding techniques
      scores['exercise'] = scores['exercise']! + 1.0;
      scores['video'] = scores['video']! + 0.5;
    }

    // Pick highest score
    final best = scores.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return best.key;
  }

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> _fetchRecentEntries(
      String uid, {required int days}) async {
    final now = DateTime.now();
    final since = now.subtract(Duration(days: days));

    final results = <Map<String, dynamic>>[];

    // Entries are stored in monthly sub-collections
    final months = _monthBuckets(since, now);
    for (final month in months) {
      try {
        final snap = await _db
            .collection('entries')
            .doc(uid)
            .collection(month)
            .where('createdAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(since))
            .orderBy('createdAt', descending: true)
            .limit(100)
            .get();
        results.addAll(snap.docs.map((d) => d.data()));
      } catch (_) {}
    }

    return results;
  }

  Map<String, int> _buildMoodFrequency(List<Map<String, dynamic>> entries) {
    final freq = <String, int>{};
    for (final e in entries) {
      final raw = (e['mood'] as String?)?.toLowerCase().trim() ?? '';
      if (raw.isEmpty) continue;
      // Normalise: strip emoji and extra words
      final normalised = _normaliseMood(raw);
      freq[normalised] = (freq[normalised] ?? 0) + 1;
    }
    return freq;
  }

  String? _dominantMood(Map<String, int> freq) {
    if (freq.isEmpty) return null;
    return freq.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  String? _peakCheckInTime(List<Map<String, dynamic>> entries) {
    final buckets = <String, int>{};
    for (final e in entries) {
      final ts = (e['createdAt'] as Timestamp?)?.toDate();
      if (ts == null) continue;
      final bucket = _hourBucket(ts.hour);
      buckets[bucket] = (buckets[bucket] ?? 0) + 1;
    }
    if (buckets.isEmpty) return null;
    return buckets.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  List<String> _recentMoods(List<Map<String, dynamic>> entries, {int limit = 6}) {
    final seen = <String>{};
    final out = <String>[];
    for (final e in entries) {
      final raw = (e['mood'] as String?)?.toLowerCase().trim() ?? '';
      if (raw.isEmpty) continue;
      final n = _normaliseMood(raw);
      if (!seen.contains(n)) {
        seen.add(n);
        out.add(n);
      }
      if (out.length >= limit) break;
    }
    return out;
  }

  List<String> _recentSuggestions(
      List<Map<String, dynamic>> entries, {required int days}) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final out = <String>[];
    for (final e in entries) {
      final ts = (e['createdAt'] as Timestamp?)?.toDate();
      if (ts == null || ts.isBefore(cutoff)) continue;
      final s = (e['suggestion'] as String?)?.trim() ?? '';
      if (s.isNotEmpty) out.add(s);
    }
    return out;
  }

  String _moodTrend(List<Map<String, dynamic>> entries) {
    if (entries.length < 4) return 'unknown';

    // Split into first half / second half (oldest → newest after reversing)
    final sorted = [...entries]
      ..sort((a, b) {
        final ta = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
        final tb = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
        return ta.compareTo(tb);
      });

    final half = sorted.length ~/ 2;
    final older = sorted.sublist(0, half);
    final newer = sorted.sublist(half);

    double score(List<Map<String, dynamic>> batch) {
      double s = 0;
      for (final e in batch) {
        final m = (e['mood'] as String?)?.toLowerCase() ?? '';
        s += _moodValence(m);
      }
      return s / batch.length;
    }

    final olderScore = score(older);
    final newerScore = score(newer);
    final delta = newerScore - olderScore;

    if (delta > 0.3) return 'improving';
    if (delta < -0.3) return 'declining';
    return 'mixed';
  }

  // Positive = good mood, Negative = bad mood
  double _moodValence(String mood) {
    if (_hasAny(mood, ['happy', 'good', 'great', 'excited', 'okay', 'calm'])) {
      return 1.0;
    }
    if (_hasAny(mood, ['anx', 'stress', 'nervous', 'overwhelm'])) return -0.5;
    if (_hasAny(mood, ['sad', 'low', 'down', 'depress', 'hopeless'])) return -1.0;
    if (_hasAny(mood, ['angry', 'frustrat', 'mad', 'irritat'])) return -0.7;
    if (_hasAny(mood, ['exhaust', 'tired', 'drained'])) return -0.4;
    return 0.0; // neutral
  }

  String _normaliseMood(String raw) {
    // Strip leading emoji (anything non-ascii at the start)
    final stripped = raw.replaceAll(RegExp(r'^[^\x00-\x7F\s]+\s*'), '').trim();
    // Keep first word only to normalise "😟 anxious" → "anxious"
    final first = stripped.split(RegExp(r'\s+')).first;
    return first.isEmpty ? raw : first;
  }

  static String _currentHourBucket() => _hourBucket(DateTime.now().hour);

  static String _hourBucket(int h) {
    if (h >= 5 && h < 12) return 'morning';
    if (h >= 12 && h < 17) return 'afternoon';
    if (h >= 17 && h < 22) return 'evening';
    return 'late_night';
  }

  static bool _hasAny(String text, List<String> needles) =>
      needles.any((n) => text.contains(n));

  List<String> _monthBuckets(DateTime start, DateTime end) {
    var s = DateTime(start.year, start.month);
    final e = DateTime(end.year, end.month);
    final out = <String>[];
    while (!s.isAfter(e)) {
      out.add(DateFormat('yyyy-MM').format(s));
      s = DateTime(s.year, s.month + 1);
    }
    return out;
  }
}