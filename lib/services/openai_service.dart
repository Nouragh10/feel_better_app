// PATH: lib/services/openai_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

/// A suggestion plus an optional link to open.
class SuggestionWithLink {
  final String suggestion;
  final String? linkUrl;

  const SuggestionWithLink({required this.suggestion, this.linkUrl});
}

/// Top-level enum for coarse mood categories.
enum _MoodCat {
  anxious,
  low,
  angry,
  exhausted,
  overwhelmed,
  stuck,
  happy,
  neutral,
  hungry,
}

class OpenAIService {
  // ---------------------------------------------------------------------------
  // PUBLIC API
  // ---------------------------------------------------------------------------

  /// Back-compat for older callers (returns only text).
  static Future<String> suggest({
    String? apiKey,
    required String mood,
    required List<String> items,
    String? uid,
    Map<String, String>? userPreferences,
  }) async {
    final r = await suggestWithLink(
      apiKey: apiKey,
      mood: mood,
      items: items,
      uid: uid,
      userPreferences: userPreferences,
    );
    return r.suggestion;
  }

  /// Returns ONE suggestion and link. (Internally picks the first of a batch.)
  static Future<SuggestionWithLink> suggestWithLink({
    String? apiKey,
    required String mood,
    required List<String> items,
    String? uid,
    int? nonce,
    Map<String, String>? userPreferences,
  }) async {
    final list = await suggestBatchWithLinks(
      apiKey: apiKey,
      mood: mood,
      items: items,
      uid: uid,
      n: 1,
      nonce: nonce,
      userPreferences: userPreferences,
    );
    return list.isNotEmpty
        ? list.first
        : const SuggestionWithLink(
            suggestion: 'Something went wrong. Please try again.',
          );
  }

  /// Returns up to [n] diverse suggestions with links (used for "redo" pool).
  /// [nonce] is a salt to encourage variety across repeated calls.
  static Future<List<SuggestionWithLink>> suggestBatchWithLinks({
    String? apiKey,
    required String mood,
    required List<String> items,
    String? uid,
    int n = 5,
    int? nonce,
    Map<String, String>? userPreferences,
  }) async {
    n = (n <= 0) ? 1 : (n > 5 ? 5 : n);

    // Read prefs once for personalization.
    Map<String, dynamic>? prefs;
    
    // Use passed userPreferences if available, otherwise try to fetch from Firestore
    if (userPreferences != null && userPreferences.isNotEmpty) {
      prefs = Map<String, dynamic>.from(userPreferences);
    } else if (uid != null) {
      try {
        final snap =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final data = snap.data();
        final p = data?['personalPreferences'];
        if (p is Map) prefs = Map<String, dynamic>.from(p);
      } catch (_) {}
    }

    final hourBucket = _hourBucket(DateTime.now());
    final energyPref =
        ((prefs?['energyPreference'] as String?) ?? 'balanced').toString().toLowerCase();
    final defaultService =
        ((prefs?['defaultMusicService'] as String?) ?? '').toString().toLowerCase();
    final List<String> recentContexts = ((prefs?['recentContexts'] as List?) ?? [])
        .map((e) => e.toString())
        .toList();

    List<String> texts;
    if ((apiKey ?? '').isEmpty) {
      // Offline fallback batch
      texts = _localSuggestionBatch(
        mood: mood,
        items: items,
        hourBucket: hourBucket,
        energyPreference: energyPref,
        n: n,
        nonce: nonce,
        userPreferences: prefs,
      );
    } else {
      // Online batch (robust plain-text format; no JSON parsing surprises)
      texts = await _onlineSuggestionBatch(
        apiKey: apiKey!,
        mood: mood,
        items: items,
        hourBucket: hourBucket,
        energyPreference: energyPref,
        recentContexts: recentContexts,
        n: n,
        nonce: nonce,
        userPreferences: prefs,
      );

      // If model returns nothing, fall back to local.
      if (texts.isEmpty) {
        texts = _localSuggestionBatch(
          mood: mood,
          items: items,
          hourBucket: hourBucket,
          energyPreference: energyPref,
          n: n,
          nonce: nonce,
          userPreferences: prefs,
        );
      }
    }

    // Enforce: every suggestion must mention an item.
    texts = texts.map((s) => _ensureItemMention(s, items)).toList();

    // Build links per suggestion.
    final out = <SuggestionWithLink>[];
    for (final t in texts) {
      final link = _personalizedLink(
        suggestion: t,
        userText: mood,
        items: items,
        prefs: prefs,
        defaultMusicService: defaultService.isEmpty ? null : defaultService,
        energyPreference: energyPref,
      );
      out.add(SuggestionWithLink(suggestion: _sanitize(t), linkUrl: link));
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // ONLINE (OpenAI) — batched plain-text format
  // ---------------------------------------------------------------------------

  static Future<List<String>> _onlineSuggestionBatch({
    required String apiKey,
    required String mood,
    required List<String> items,
    required String hourBucket,
    required String energyPreference,
    required List<String> recentContexts,
    required int n,
    int? nonce,
    Map<String, dynamic>? userPreferences,
  }) async {
    final near = (items.isNotEmpty ? items.join(', ') : 'something nearby');
    final nonceText = (nonce == null) ? '' : '\nNonce: $nonce';

    // Build user preferences context
    String prefsContext = '';
    if (userPreferences != null && userPreferences.isNotEmpty) {
      prefsContext = '\n\nUser preferences (incorporate when relevant):';
      if (userPreferences['favoriteSongSad'] != null) {
        prefsContext += '\n- Favorite song when sad: ${userPreferences['favoriteSongSad']}';
      }
      if (userPreferences['favoriteSongAnxious'] != null) {
        prefsContext += '\n- Favorite song when anxious: ${userPreferences['favoriteSongAnxious']}';
      }
      if (userPreferences['favoritePodcast'] != null) {
        prefsContext += '\n- Favorite podcast: ${userPreferences['favoritePodcast']}';
      }
      if (userPreferences['comfortFood'] != null) {
        prefsContext += '\n- Comfort food: ${userPreferences['comfortFood']}';
      }
      if (userPreferences['goToActivity'] != null) {
        prefsContext += '\n- Go-to activity: ${userPreferences['goToActivity']}';
      }
      if (userPreferences['trustedPerson'] != null) {
        prefsContext += '\n- Trusted person: ${userPreferences['trustedPerson']}';
      }
      if (userPreferences['safeSpace'] != null) {
        prefsContext += '\n- Safe space: ${userPreferences['safeSpace']}';
      }
    }

    // We ask the model for "exactly N lines, each starting with '- '", so we can
    // reliably split without JSON parsing issues.
    final prompt = '''
You're a brief behavioral activation coach. The user gives a feeling and nearby items.
Return EXACTLY $n unique, tiny, safe, highly doable tasks (<= 2 short sentences each).
Output format STRICT: one line per suggestion, each starting with "- " and nothing else.

Rules:
- You MUST reference at least ONE of the provided nearby items BY NAME in EACH task (e.g., "candle", "phone"), unless using it would be unsafe.
- If input suggests LISTENING (song/music/headphones), prefer a SONG action.
- ONLY suggest a PODCAST when the user explicitly mentions "podcast".
- If input suggests WATCHING, prefer a short video action.
- If the user is HUNGRY (hungry/hangry/food/snack/starving/eat), suggest opening a quick recipe and making a small snack. No music there.
- Do NOT name specific song/podcast/video titles unless the user provided them. Say "a calming song", "your favorite playlist", etc. The app supplies the link.
- No multiple choices or "or". Each line is one clear action under ~2 minutes.
$prefsContext

Context hints (light bias only):
- Time of day: $hourBucket
- Energy preference: $energyPreference
- Recent contexts: ${recentContexts.join(', ')}$nonceText

Feeling: "$mood"
Nearby: "$near"

Now output exactly $n lines, each starting with "- ".
''';

    final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    // Small temp jitter if a nonce is present (encourages variety run-to-run).
    final double baseTemp = 0.7;
    final double jitter =
        (nonce == null) ? 0.0 : ((nonce % 3) - 1) * 0.05; // -0.05, 0, +0.05
    final double temp = (baseTemp + jitter).clamp(0.2, 1.0);

    final body = jsonEncode({
      'model': 'gpt-4o-mini',
      'temperature': temp,
      'messages': [
        {
          'role': 'system',
          'content':
              'Return only the requested lines. No extra commentary. Be concrete, compassionate, and safe. Use user preferences when relevant.'
        },
        {'role': 'user', 'content': prompt},
      ],
    });

    try {
      final resp = await http
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        return <String>[];
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final choices = data['choices'] as List?;
      final content = (choices != null &&
              choices.isNotEmpty &&
              choices.first is Map &&
              (choices.first as Map)['message'] is Map)
          ? (((choices.first as Map)['message'] as Map)['content'] as String?)
          : null;

      if (content == null || content.trim().isEmpty) {
        return <String>[];
      }

      // Parse "- " lines, trim, unique, non-empty.
      final lines = content
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.startsWith('- '))
          .map((s) => s.substring(2).trim())
          .where((s) => s.isNotEmpty)
          .toList();

      // Deduplicate while preserving order.
      final seen = <String>{};
      final out = <String>[];
      for (final l in lines) {
        final k = l.toLowerCase();
        if (!seen.contains(k)) {
          seen.add(k);
          out.add(l);
        }
      }
      // Clip to requested n.
      return out.length > n ? out.sublist(0, n) : out;
    } on TimeoutException {
      return <String>[];
    } catch (_) {
      return <String>[];
    }
  }

  // ---------------------------------------------------------------------------
  // OFFLINE FALLBACKS (no API key)
  // ---------------------------------------------------------------------------

  static List<String> _localSuggestionBatch({
    required String mood,
    required List<String> items,
    required String hourBucket,
    required String energyPreference,
    required int n,
    int? nonce,
    Map<String, dynamic>? userPreferences,
  }) {
    final base = <String>[];

    // Prefer an item-specific action first when a physical (non-enabler) item exists.
    final thing = items.isNotEmpty ? items.first.trim() : '';
    if (thing.isNotEmpty && !_isEnabler(thing)) {
      base.addAll(_itemActionVariants(thing));
    } else {
      // No good physical item → seed with generic single suggestion.
      base.add(_localSuggestion(
        mood,
        items,
        hourBucket: hourBucket,
        energyPreference: energyPreference,
        userPreferences: userPreferences,
      ));
    }

    final m = mood.toLowerCase();

    // Check for user preferences and incorporate them
    if (userPreferences != null) {
      // Phone + sad mood + favorite song
      final hasPhone = items.any((i) => i.toLowerCase().contains('phone'));
      if (hasPhone && _hasAny(m, ['sad', 'low', 'down']) && userPreferences['favoriteSongSad'] != null) {
        final song = userPreferences['favoriteSongSad'];
        base.add('On your phone, play "$song" - your go-to song when feeling low.');
      }
      // Phone + anxious mood + calming song
      if (hasPhone && _hasAny(m, ['anx', 'nervous', 'panic', 'tense']) && userPreferences['favoriteSongAnxious'] != null) {
        final song = userPreferences['favoriteSongAnxious'];
        base.add('On your phone, play "$song" - your calming song.');
      }
      // Go-to activity
      if (userPreferences['goToActivity'] != null) {
        final activity = userPreferences['goToActivity'];
        base.add('Try $activity for 2 minutes - your go-to activity.');
      }
    }

    // Hungry → diversify with snack/recipe variants only.
    if (_hasAny(m, ['hungry', 'hangry', 'starv', 'snack', 'food', 'eat'])) {
      base.addAll([
        'Open a 5-minute snack recipe and prepare just the first step.',
        'Fill a glass of water and eat a small snack while taking five slow breaths.',
        'Make a quick toast or fruit snack and notice the temperature and texture for 30 seconds.',
      ]);
    } else if (_wantsListen(userText: m) || thing.contains('headphone') || _isEnabler(thing)) {
      // Device-based listening variants.
      final device = thing.isEmpty ? 'phone' : thing;
      base.addAll([
        'On your $device, put on a calm song for one minute and breathe with the rhythm.',
        'On your $device, play a feel-good song for one minute and gently sway your shoulders.',
      ]);
    } else if (_wantsWatch(userText: m)) {
      base.addAll([
        'Watch a cozy, quiet clip for one minute with the volume low.',
        'Watch a short uplifting clip and notice one thing that makes you smile.',
      ]);
    } else if (_hasAny(m, ['anx', 'nervous', 'panic', 'tense'])) {
      base.addAll([
        if (thing.isNotEmpty) 'Hold the $thing and trace its outline for 5 slow breaths.',
        'Rub your thumb and finger together and count ten slow breaths.',
        'Name five things you can see, four you can touch, three you can hear.',
      ]);
    } else if (_hasAny(m, ['low', 'sad', 'down'])) {
      base.addAll([
        'Play a feel-good song for one minute and gently sway to the beat.',
        'Open your photos and favorite the first picture that makes you smile.',
      ]);
    } else if (_hasAny(m, ['overwhelm', 'stress'])) {
      base.addAll([
        'Stack or tidy 5 small items near you, then stop. Say "good enough."',
        'Write the tiniest next step on a sticky note and do only that.',
      ]);
    } else if (_hasAny(m, ['angry', 'frustrat', 'irritat', 'mad'])) {
      base.addAll([
        if (thing.isNotEmpty)
          'Unclench your jaw, drop your shoulders, and take 10 slow breaths while lightly squeezing the $thing.',
        'Shake out your hands for 30 seconds, then breathe slowly for 30 seconds.',
      ]);
    } else if (_hasAny(m, ['exhaust', 'tired', 'drained', 'sleepy', 'wiped'])) {
      base.addAll([
        'Sit tall and roll your shoulders while taking 6 slow breaths.',
        'Stand up, stretch your neck gently, and breathe for one minute.',
      ]);
    } else if (_hasAny(m, ['stuck', 'no motivation', 'procrast'])) {
      base.addAll([
        'Stand up and touch the nearest wall for 10 seconds.',
        'Set a 60-second timer and put one object away, then stop.',
      ]);
    } else {
      base.addAll([
        if (thing.isNotEmpty)
          'Name one feeling out loud, then hold the $thing while counting 10 slow breaths.',
        'Look around and name three colors you see, then breathe slowly.',
      ]);
    }

    // If a nonce is provided, rotate the list deterministically to vary ordering.
    if (nonce != null && base.length > 1) {
      final k = nonce.abs() % base.length;
      final rotated = [...base.sublist(k), ...base.sublist(0, k)];
      base
        ..clear()
        ..addAll(rotated);
    }

    // Deduplicate and clip to n.
    final seen = <String>{};
    final out = <String>[];
    for (final s in base) {
      final k = s.toLowerCase();
      if (!seen.contains(k)) {
        seen.add(k);
        out.add(s);
      }
      if (out.length >= n) break;
    }

    // As a last resort, pad with generic tiny actions.
    while (out.length < n) {
      out.add('Take five slow breaths and relax your shoulders.');
    }

    // Enforce: every suggestion must mention an item.
    return out.map((s) => _ensureItemMention(s, items)).toList();
  }

  /// Single offline suggestion used as building block.
  static String _localSuggestion(
    String mood,
    List<String> items, {
    required String hourBucket,
    required String energyPreference,
    Map<String, dynamic>? userPreferences,
  }) {
    final thing = items.isNotEmpty ? items.first : 'something nearby';
    final m = mood.toLowerCase();

    // Check for phone and user preferences first
    final hasPhone = items.any((i) => i.toLowerCase().contains('phone'));
    if (hasPhone && userPreferences != null) {
      if (_hasAny(m, ['sad', 'low', 'down']) && userPreferences['favoriteSongSad'] != null) {
        final song = userPreferences['favoriteSongSad'];
        return 'On your phone, play "$song" - your go-to song when feeling low.';
      }
      if (_hasAny(m, ['anx', 'nervous', 'panic', 'tense']) && userPreferences['favoriteSongAnxious'] != null) {
        final song = userPreferences['favoriteSongAnxious'];
        return 'On your phone, play "$song" - your calming song.';
      }
    }

    if (_hasAny(m, ['hungry', 'hangry', 'starv', 'snack', 'food', 'eat'])) {
      return 'Open a quick 5-minute recipe and make a small snack. Take a few bites and notice your energy.';
    }

    final wantsListen = _wantsListen(userText: mood);
    final wantsWatch = _wantsWatch(userText: mood);

    if (wantsListen) {
      if (m.contains('podcast')) {
        return 'Press play on a short uplifting podcast and take slow breaths for a minute.';
      }
      return energyPreference == 'gentle' || hourBucket == 'late_night'
          ? 'Put on a calm song for one minute and breathe with the rhythm.'
          : 'Put on your headphones and play a song that fits your mood for one minute.';
    }

    if (wantsWatch) {
      final windDown = hourBucket == 'late_night';
      return windDown
          ? 'Watch a cozy, quiet clip for one minute with the volume low, then notice your breath.'
          : 'Watch a short uplifting clip for one minute and notice one thing that makes you smile.';
    }

    if (_hasAny(m, ['anx', 'nervous', 'panic', 'tense'])) {
      return 'Hold the $thing and trace its outline for 5 slow breaths. Whisper one calming word on each exhale.';
    }
    if (_hasAny(m, ['low', 'sad', 'down'])) {
      final gentle = energyPreference == 'gentle' || hourBucket == 'late_night';
      return gentle
          ? 'Play a calm song for one minute and breathe with the rhythm.'
          : 'Play a feel-good song for one minute and gently sway to the beat.';
    }
    if (_hasAny(m, ['overwhelm', 'stress'])) {
      return 'Set a 60-second timer. Tidy or stack 5 small items near you, then stop. Say "good enough."';
    }
    if (_hasAny(m, ['angry', 'frustrat', 'irritat', 'mad'])) {
      return 'Unclench your jaw and drop your shoulders. Take 10 slow breaths while lightly squeezing the $thing.';
    }
    if (_hasAny(m, ['exhaust', 'tired', 'drained', 'sleepy', 'wiped']) ||
        (m.contains('cant') && m.contains('bed')) ||
        (m.contains("can't") && m.contains('bed'))) {
      final gentle = energyPreference == 'gentle';
      return gentle
          ? 'Lie back or sit tall and take 6 slow breaths while you lightly stretch your neck and shoulders.'
          : 'Stand up, roll your shoulders, and take 6 slow breaths while stretching your neck.';
    }
    if (_hasAny(m, ['stuck', 'no motivation', 'procrast'])) {
      return 'Stand up and touch the nearest wall for 10 seconds. One tiny step counts.';
    }
    final gentle = energyPreference == 'gentle' || hourBucket == 'late_night';
    return gentle
        ? 'Name one feeling out loud, then hold the $thing for one quiet minute while counting 10 slow breaths.'
        : 'Name one feeling out loud, then interact with the $thing for one minute while counting 10 slow breaths.';
  }

  // ---------------------------------------------------------------------------
  // LINK LOGIC
  // ---------------------------------------------------------------------------

  static String? _personalizedLink({
    required String suggestion,
    required String userText,
    required List<String> items,
    Map<String, dynamic>? prefs,
    String? defaultMusicService,
    String? energyPreference,
  }) {
    final text = '${suggestion.toLowerCase()} ${userText.toLowerCase()}';
    final itemsText = items.join(' ').toLowerCase();

    final hasHeadphones = itemsText.contains('head') ||
        itemsText.contains('earbud') ||
        itemsText.contains('airpod') ||
        itemsText.contains('ear pod') ||
        itemsText.contains('speaker');

    final explicitPodcast = RegExp(r'\bpodcasts?\b').hasMatch(text);
    final explicitSong = RegExp(r'\b(song|music|playlist)\b').hasMatch(text);
    final wantsWatch = _wantsWatch(userText: text);

    final preferPodcast = explicitPodcast && !explicitSong;
    final preferSong = explicitSong || (hasHeadphones && !preferPodcast);

    final cat = _classifyMood(userText);

    // Hungry ALWAYS → recipe link.
    if (cat == _MoodCat.hungry) {
      return _webSearch('quick easy 5 minute recipe healthy snack');
    }

    // SONG preference.
    if (preferSong) {
      switch (cat) {
        case _MoodCat.anxious:
          return _prefOrSearch(
            prefs?['favoriteSongAnxious'] as String? ?? prefs?['calmSong'] as String? ?? prefs?['happySong'] as String?,
            fallback: 'calming instrumental song 2 minutes',
            defaultService: defaultMusicService,
          );
        case _MoodCat.angry:
          return _prefOrSearch(
            prefs?['energizeSong'] as String?,
            fallback: 'energetic clean song quick motivation',
            defaultService: defaultMusicService,
          );
        case _MoodCat.exhausted:
          return _prefOrSearch(
            prefs?['energizeSong'] as String?,
            fallback: 'gentle motivational song 2 minutes',
            defaultService: defaultMusicService,
          );
        case _MoodCat.low:
          return _prefOrSearch(
            prefs?['favoriteSongSad'] as String? ?? prefs?['happySong'] as String? ?? prefs?['energizeSong'] as String?,
            fallback: 'feel good song quick mood boost',
            defaultService: defaultMusicService,
          );
        case _MoodCat.overwhelmed:
          final genre = (prefs?['focusGenre'] as String?)?.trim();
          final q = '${(genre?.isNotEmpty == true) ? '$genre ' : ''}lofi focus 2 minutes';
          return _musicSearch(q, defaultService: defaultMusicService);
        case _MoodCat.stuck:
          return _musicSearch('upbeat get moving song 1 minute', defaultService: defaultMusicService);
        case _MoodCat.happy:
          return _prefOrSearch(
            prefs?['happySong'] as String?,
            fallback: 'happy upbeat song',
            defaultService: defaultMusicService,
          );
        case _MoodCat.neutral:
          return _musicSearch('feel good song 1 minute', defaultService: defaultMusicService);
        case _MoodCat.hungry:
          return _webSearch('quick easy 5 minute recipe healthy snack');
      }
    }

    // PODCAST preference.
    if (preferPodcast) {
      final fav = (prefs?['favoritePodcast'] as String?)?.trim();
      return (fav != null && fav.isNotEmpty)
          ? _mediaLinkFromPref(fav,
              fallbackQuery: 'short uplifting podcast 5 minutes',
              defaultService: defaultMusicService)
          : _ytSearch('short uplifting podcast 5 minutes');
    }

    // WATCH preference / fallback.
    if (wantsWatch) {
      switch (cat) {
        case _MoodCat.anxious:
          final kw = (prefs?['windDownKeyword'] as String?)?.trim();
          return _ytSearch(kw?.isNotEmpty == true ? kw! : 'guided box breathing 2 minutes');
        case _MoodCat.angry:
          return _ytSearch('shake it out exercise 1 minute stress relief');
        case _MoodCat.exhausted:
          return _ytSearch('quick stretch in bed 2 minutes gentle');
        case _MoodCat.low:
          return _ytSearch('short uplifting video quick mood boost');
        case _MoodCat.overwhelmed:
          return _ytSearch('visualization calm 2 minutes');
        case _MoodCat.stuck:
          return _ytSearch('5-4-3-2-1 grounding 2 minutes');
        case _MoodCat.happy:
          return _ytSearch('uplifting short video 2 minutes');
        case _MoodCat.neutral:
          return _ytSearch('short wholesome clip 2 minutes');
        case _MoodCat.hungry:
          return _ytSearch('5 minute snack recipe video');
      }
    }

    // No clear signal → if headphones nearby, lean music; else no link.
    if (hasHeadphones) {
      return _prefOrSearch(
        _pickFirstNonEmpty([
          prefs?['happySong'] as String?,
          prefs?['calmSong'] as String?,
          prefs?['energizeSong'] as String?,
        ]),
        fallback: 'feel good song quick boost',
        defaultService: defaultMusicService,
      );
    }

    return null;
  }

  static String? _prefOrSearch(String? pref,
      {required String fallback, String? defaultService}) {
    final v = (pref ?? '').trim();
    if (v.isEmpty) {
      return _musicSearch(fallback, defaultService: defaultService);
    }
    return _mediaLinkFromPref(v,
        fallbackQuery: fallback, defaultService: defaultService);
    }

  static String _sanitize(String s) {
    final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t.length > 240 ? '${t.substring(0, 240)}…' : t;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static _MoodCat _classifyMood(String text) {
    final t = text.toLowerCase();
    if (_hasAny(t, ['hungry', 'hangry', 'starv', 'snack', 'food', 'eat'])) {
      return _MoodCat.hungry;
    }
    if (_hasAny(t, ['anx', 'nervous', 'panic', 'tense'])) return _MoodCat.anxious;
    if (_hasAny(t, ['angry', 'mad', 'frustrat', 'irritat'])) return _MoodCat.angry;
    if (_hasAny(t, ['exhaust', 'tired', 'drained', 'sleepy', 'wiped']) ||
        (t.contains('cant') && t.contains('bed')) ||
        (t.contains("can't") && t.contains('bed'))) return _MoodCat.exhausted;
    if (_hasAny(t, ['overwhelm', 'stress'])) return _MoodCat.overwhelmed;
    if (_hasAny(t, ['stuck', 'no motivation', 'procrast'])) return _MoodCat.stuck;
    if (_hasAny(t, ['low', 'sad', 'down', 'blue'])) return _MoodCat.low;
    if (_hasAny(t, ['happy', 'good', 'excited'])) return _MoodCat.happy;
    return _MoodCat.neutral;
  }

  static bool _wantsListen({required String userText}) {
    final t = userText.toLowerCase();
    return t.contains('listen') ||
        t.contains('song') ||
        t.contains('music') ||
        t.contains('playlist') ||
        t.contains('headphone') ||
        t.contains('earbud') ||
        t.contains('airpod') ||
        t.contains('speaker') ||
        t.contains('podcast');
  }

  static bool _wantsWatch({required String userText}) {
    final t = userText.toLowerCase();
    return t.contains('watch') || t.contains('video') || t.contains('clip');
  }

  static bool _hasAny(String text, List<String> needles) {
    final t = text.toLowerCase();
    return needles.any((n) => t.contains(n));
  }

  static String? _pickFirstNonEmpty(List<String?> xs) {
    for (final x in xs) {
      final v = x?.trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  static bool _isEnabler(String item) {
    final t = item.toLowerCase();
    return t.contains('phone') ||
        t.contains('headphone') ||
        t.contains('earbud') ||
        t.contains('airpod') ||
        t.contains('speaker');
  }

  static List<String> _itemActionVariants(String itemRaw) {
    final item = itemRaw.toLowerCase();
    String i(String s) => s.replaceAll('\$item', itemRaw);

    // Simple mapping with 1–2 concrete actions per common item.
    final map = <String, List<String>>{
      'candle': [
        i('Hold the \$item and trace its outline with your finger for 5 slow breaths.'),
        i('Light the \$item safely and watch the flame as you inhale for 4 and exhale for 6.'),
      ],
      'book': [
        i('Open the \$item to any page and read three sentences out loud, slowly.'),
        i('Scan the cover of the \$item for 30 seconds while breathing in for 4, out for 6.'),
      ],
      'plant': [
        i('Look closely at the leaves of the \$item for 30 seconds and count five shades of green.'),
        i('Lightly touch a leaf on the \$item and take 6 slow breaths, noticing the texture.'),
      ],
      'water': [
        i('Sip the \$item slowly 5 times, pausing between sips to notice the coolness.'),
      ],
      'bottle': [
        i('Roll the \$item gently between your palms for 30 seconds and breathe out longer than in.'),
      ],
      'pillow': [
        i('Hug the \$item and take 6 slow breaths, relaxing your jaw and shoulders.'),
      ],
      'blanket': [
        i('Wrap the \$item around your shoulders and take 6 slow breaths, feeling the weight.'),
      ],
      'window': [
        i('Stand by the \$item and count three things you can see outside, breathing slowly.'),
      ],
      'pen': [
        i('With the \$item, write one kind sentence to yourself and read it out loud.'),
      ],
      'notebook': [
        i('Open the \$item and jot three words for how you feel, then breathe out slowly.'),
      ],
    };

    for (final key in map.keys) {
      if (item.contains(key)) return map[key]!;
    }
    // Unknown item → generic but still item-referencing.
    return [
      i('Hold the \$item and trace its outline for 5 slow breaths.'),
    ];
  }

  // Ensures the text mentions at least one item; if not, prefixes with the first item.
  static String _ensureItemMention(String text, List<String> items) {
    if (items.isEmpty) return text;
    if (_mentionsAny(text, items)) return text;
    final item = items.first.trim();
    if (item.isEmpty) return text;
    // Lowercase first letter of the original sentence when we prefix to keep it flowing.
    String lowerFirst(String s) =>
        s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);
    return 'With the $item, ${lowerFirst(text)}';
  }

  static bool _mentionsAny(String text, List<String> items) {
    final t = text.toLowerCase();
    for (final raw in items) {
      final w = raw.trim().toLowerCase();
      if (w.isEmpty) continue;
      // word-boundary-ish match to avoid partials
      if (RegExp(r'(^|[^a-z])' + RegExp.escape(w) + r'([^a-z]|$)').hasMatch(t)) {
        return true;
      }
    }
    return false;
  }

  static String _musicSearch(String q, {String? defaultService}) {
    final svc = (defaultService ?? '').toLowerCase();
    if (svc == 'spotify') {
      return 'https://open.spotify.com/search/${Uri.encodeComponent(q)}';
    }
    if (svc == 'apple') {
      return 'https://music.apple.com/search?term=${Uri.encodeComponent(q)}';
    }
    if (svc == 'youtube') {
      return _ytSearch(q);
    }
    return _ytSearch(q);
  }

  static String _ytSearch(String q) =>
      'https://www.youtube.com/results?search_query=${Uri.encodeComponent(q)}';

  static String _webSearch(String q) =>
      'https://www.google.com/search?q=${Uri.encodeComponent(q)}';

  static String _mediaLinkFromPref(String? value,
      {String? fallbackQuery, String? defaultService}) {
    final v = (value ?? '').trim();
    if (v.isEmpty) {
      return _musicSearch(fallbackQuery ?? 'feel good song quick boost',
          defaultService: defaultService);
    }
    if (_looksLikeUrl(v)) return v;
    return _musicSearch(v, defaultService: defaultService);
  }

  static bool _looksLikeUrl(String s) {
    final t = s.toLowerCase();
    if (t.startsWith('http://') || t.startsWith('https://')) return true;
    if (t.startsWith('youtu.be/') || t.startsWith('youtube.com/')) return true;
    if (t.startsWith('open.spotify.com/')) return true;
    if (t.startsWith('music.apple.com/')) return true;
    return false;
  }

  static String _hourBucket(DateTime now) {
    final h = now.hour;
    if (h >= 5 && h < 12) return 'morning';
    if (h >= 12 && h < 17) return 'day';
    if (h >= 17 && h < 22) return 'evening';
    return 'late_night';
  }
}