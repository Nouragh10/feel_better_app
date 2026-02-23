// PATH: lib/services/openai_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'mood_pattern_service.dart';

class CrisisDetectionResult {
  final bool isCrisis;
  final String? safetyMessage;
  final List<String> hotlines;

  CrisisDetectionResult({
    required this.isCrisis,
    this.safetyMessage,
    this.hotlines = const [],
  });
}

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

  static CrisisDetectionResult detectCrisis({
    required String mood,
    required List<String> items,
  }) {
    final moodLower = mood.toLowerCase();
    final itemsLower = items.map((i) => i.toLowerCase()).toList();
    
    final severeMoodIndicators = [
      'suicidal', 'suicide', 'kill myself', 'end my life', 'want to die',
      'better off dead', 'no reason to live', 'can\'t go on',
      'hurt myself', 'self harm', 'self-harm',
    ];
    
    final highRiskMoodIndicators = [
      'depressed', 'hopeless', 'worthless', 'desperate', 'unbearable',
      'can\'t take it',
    ];
    
    final dangerousItems = [
      'knife', 'knives', 'blade', 'razor', 'gun', 'pistol', 'firearm',
      'weapon', 'pills', 'medication', 'rope', 'belt',
    ];
    
    final hasSevereMood = severeMoodIndicators.any((i) => moodLower.contains(i));
    if (hasSevereMood) {
      return CrisisDetectionResult(
        isCrisis: true,
        safetyMessage: 'We\'re concerned about your safety. Please reach out to someone who can help immediately.',
        hotlines: _getCrisisHotlines(),
      );
    }
    
    final hasHighRiskMood = highRiskMoodIndicators.any((i) => moodLower.contains(i));
    final hasDangerousItem = itemsLower.any((item) =>
        dangerousItems.any((d) => item.contains(d)));
    
    if (hasHighRiskMood && hasDangerousItem) {
      return CrisisDetectionResult(
        isCrisis: true,
        safetyMessage: 'Your safety is our priority. Please reach out for immediate support.',
        hotlines: _getCrisisHotlines(),
      );
    }
    
    return CrisisDetectionResult(isCrisis: false);
  }
  
  static List<String> _getCrisisHotlines() {
    return [
      '988 - Suicide & Crisis Lifeline (US)',
      '1-800-273-8255 - National Suicide Prevention Lifeline',
      'Text "HELLO" to 741741 - Crisis Text Line',
      '1-800-799-7233 - National Domestic Violence Hotline',
    ];
  }

  static String _formatCrisisResponse(CrisisDetectionResult crisis) {
    final buffer = StringBuffer();
    buffer.writeln(crisis.safetyMessage);
    buffer.writeln();
    buffer.writeln('Crisis Resources:');
    for (final hotline in crisis.hotlines) {
      buffer.writeln('• $hotline');
    }
    buffer.writeln();
    buffer.writeln('You are not alone. Help is available 24/7.');
    return buffer.toString();
  }

  // ---------------------------------------------------------------------------
  // VARIATION-BASED SUGGESTION (now pattern-aware)
  // ---------------------------------------------------------------------------

  static Future<SuggestionWithLink> suggestWithVariation({
    String? apiKey,
    required String mood,
    required List<String> items,
    Map<String, String>? userPreferences,
    String? contentType,
    int variationIndex = 0,
    // NEW: pass in a pre-fetched insight to avoid redundant Firestore reads
    MoodInsight? moodInsight,
  }) async {
    final prefs = userPreferences ?? {};
    final insight = moodInsight ?? const MoodInsight();

    // Smart content type selection (uses pattern data when no explicit type)
    final effectiveContentType = contentType ??
        MoodPatternService.recommendContentType(
          mood: mood,
          insight: insight,
          items: items,
          hourBucket: _hourBucket(DateTime.now()),
        );
    
    switch (effectiveContentType) {
      case 'song':
        return _generateSongSuggestion(
          mood: mood, items: items, prefs: prefs,
          variationIndex: variationIndex, apiKey: apiKey, insight: insight,
        );
      case 'podcast':
        return _generatePodcastSuggestion(
          mood: mood, items: items, prefs: prefs,
          variationIndex: variationIndex, apiKey: apiKey, insight: insight,
        );
      case 'video':
        return _generateVideoSuggestion(
          mood: mood, items: items, prefs: prefs,
          variationIndex: variationIndex, apiKey: apiKey, insight: insight,
        );
      case 'exercise':
        return _generateExerciseSuggestion(
          mood: mood, items: items, prefs: prefs,
          variationIndex: variationIndex, apiKey: apiKey, insight: insight,
        );
      default:
        return _generateExerciseSuggestion(
          mood: mood, items: items, prefs: prefs,
          variationIndex: variationIndex, apiKey: apiKey, insight: insight,
        );
    }
  }

  // ---------------------------------------------------------------------------
  // SONG SUGGESTION
  // ---------------------------------------------------------------------------

  static Future<SuggestionWithLink> _generateSongSuggestion({
    required String mood,
    required List<String> items,
    required Map<String, String> prefs,
    required int variationIndex,
    required MoodInsight insight,
    String? apiKey,
  }) async {
    final device = items.firstWhere(
      (i) => i.toLowerCase().contains('phone') || 
             i.toLowerCase().contains('tablet') ||
             i.toLowerCase().contains('laptop'),
      orElse: () => 'phone',
    );
    
    final moodLower = mood.toLowerCase();
    final isAnxious = _hasAny(moodLower, ['anx', 'nervous', 'panic', 'tense']);
    final isSad = _hasAny(moodLower, ['sad', 'low', 'down', 'blue']);
    
    String? favoriteSong;
    if (isAnxious) {
      favoriteSong = prefs['favoriteSongAnxious'];
    } else if (isSad) {
      favoriteSong = prefs['favoriteSongSad'];
    }
    
    String suggestion;
    String? link;
    
    if (variationIndex == 0 && favoriteSong != null && favoriteSong.isNotEmpty) {
      suggestion = 'On your $device, play "$favoriteSong" and take slow breaths for 2 minutes.';
      link = _musicSearch(favoriteSong);
    } else if (apiKey != null && apiKey.isNotEmpty) {
      final similarSong = await _getSimilarSong(
        apiKey: apiKey,
        mood: mood,
        favoriteSong: favoriteSong,
        variationIndex: variationIndex,
        insight: insight,
      );
      suggestion = 'On your $device, play "$similarSong" and let the music ease your mind for 2 minutes.';
      link = _musicSearch(similarSong);
    } else {
      final genre = _getSongGenre(mood, variationIndex);
      suggestion = 'On your $device, play a $genre song for 2 minutes and breathe with the rhythm.';
      link = _musicSearch('$genre music 2 minutes');
    }
    
    return SuggestionWithLink(suggestion: suggestion, linkUrl: link);
  }

  static Future<String> _getSimilarSong({
    required String apiKey,
    required String mood,
    String? favoriteSong,
    required int variationIndex,
    required MoodInsight insight,
  }) async {
    final patternContext = insight.toPromptContext();
    final exclusion = insight.toExclusionHint();

    final prompt = favoriteSong != null
        ? '''You are a music recommendation expert. The user likes "$favoriteSong" when feeling $mood.
${patternContext.isNotEmpty ? patternContext : ''}
Suggest ONE similar song (artist - title format) with a similar vibe or genre.
Make it different from the favorite but emotionally aligned.
Variation #$variationIndex — suggest something unique each time.
${exclusion.isNotEmpty ? exclusion : ''}
Return ONLY the song name in format: "Artist - Song Title"'''
        : '''Suggest ONE ${mood.toLowerCase()} song that would help someone feeling $mood.
${patternContext.isNotEmpty ? patternContext : ''}
Variation #$variationIndex — make each suggestion unique.
${exclusion.isNotEmpty ? exclusion : ''}
Return ONLY the song name in format: "Artist - Song Title"''';

    try {
      final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'temperature': (0.8 + variationIndex * 0.1).clamp(0.0, 1.2),
          'messages': [
            {'role': 'system', 'content': 'You are a music expert. Return only song names.'},
            {'role': 'user', 'content': prompt},
          ],
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        return content.trim().replaceAll('"', '');
      }
    } catch (_) {}
    
    return _getSongGenre(mood, variationIndex);
  }

  static String _getSongGenre(String mood, int variationIndex) {
    final moodLower = mood.toLowerCase();
    
    if (_hasAny(moodLower, ['anx', 'nervous', 'panic'])) {
      final options = ['calming piano', 'ambient meditation', 'lo-fi chill', 'nature sounds'];
      return options[variationIndex % options.length];
    }
    if (_hasAny(moodLower, ['sad', 'low', 'down'])) {
      final options = ['uplifting pop', 'feel-good indie', 'happy acoustic', 'motivational'];
      return options[variationIndex % options.length];
    }
    if (_hasAny(moodLower, ['angry', 'frustrat'])) {
      final options = ['energetic workout', 'empowering rock', 'intense electronic', 'powerful indie'];
      return options[variationIndex % options.length];
    }
    
    final options = ['peaceful instrumental', 'gentle acoustic', 'soothing jazz', 'calm classical'];
    return options[variationIndex % options.length];
  }

  // ---------------------------------------------------------------------------
  // PODCAST SUGGESTION
  // ---------------------------------------------------------------------------

  static Future<SuggestionWithLink> _generatePodcastSuggestion({
    required String mood,
    required List<String> items,
    required Map<String, String> prefs,
    required int variationIndex,
    required MoodInsight insight,
    String? apiKey,
  }) async {
    final device = items.firstWhere(
      (i) => i.toLowerCase().contains('phone') || i.toLowerCase().contains('tablet'),
      orElse: () => 'phone',
    );
    
    final favoritePodcast = prefs['favoritePodcast'];
    
    String suggestion;
    String? link;
    
    if (variationIndex == 0 && favoritePodcast != null && favoritePodcast.isNotEmpty) {
      suggestion = 'On your $device, listen to a 5-minute segment from "$favoritePodcast".';
      link = _ytSearch(favoritePodcast);
    } else if (apiKey != null && apiKey.isNotEmpty) {
      final topic = await _getSimilarPodcast(
        apiKey: apiKey,
        mood: mood,
        favoritePodcast: favoritePodcast,
        variationIndex: variationIndex,
        insight: insight,
      );
      suggestion = 'On your $device, listen to a short podcast about $topic for 5 minutes.';
      link = _ytSearch('$topic podcast 5 minutes');
    } else {
      final topics = ['mindfulness', 'motivation', 'positive psychology', 'self-care', 'gratitude'];
      final topic = topics[variationIndex % topics.length];
      suggestion = 'On your $device, listen to a $topic podcast for 5 minutes.';
      link = _ytSearch('$topic podcast short');
    }
    
    return SuggestionWithLink(suggestion: suggestion, linkUrl: link);
  }

  static Future<String> _getSimilarPodcast({
    required String apiKey,
    required String mood,
    String? favoritePodcast,
    required int variationIndex,
    required MoodInsight insight,
  }) async {
    final patternContext = insight.toPromptContext();
    final exclusion = insight.toExclusionHint();

    final prompt = favoritePodcast != null
        ? '''The user likes "$favoritePodcast" podcast. Suggest ONE similar podcast topic or theme
that would help with feeling $mood.
${patternContext.isNotEmpty ? patternContext : ''}
Variation #$variationIndex.
${exclusion.isNotEmpty ? exclusion : ''}
Return ONLY a short topic name (2-4 words).'''
        : '''Suggest ONE podcast topic that would help someone feeling $mood.
${patternContext.isNotEmpty ? patternContext : ''}
Variation #$variationIndex.
${exclusion.isNotEmpty ? exclusion : ''}
Return ONLY a short topic name (2-4 words).''';

    try {
      final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'temperature': 0.9,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['choices'][0]['message']['content'] as String).trim();
      }
    } catch (_) {}
    
    return 'mindfulness and calm';
  }

  // ---------------------------------------------------------------------------
  // VIDEO SUGGESTION (now pattern-aware)
  // ---------------------------------------------------------------------------

  static Future<SuggestionWithLink> _generateVideoSuggestion({
    required String mood,
    required List<String> items,
    required Map<String, String> prefs,
    required int variationIndex,
    required MoodInsight insight,
    String? apiKey,
  }) async {
    final device = items.firstWhere(
      (i) => i.toLowerCase().contains('phone') || 
             i.toLowerCase().contains('tablet') ||
             i.toLowerCase().contains('laptop'),
      orElse: () => 'phone',
    );
    
    final moodLower = mood.toLowerCase();

    // Expand pool based on trend — declining mood → more grounding options
    final extraVideos = insight.moodTrend == 'declining'
        ? ['self-compassion meditation short', 'body scan relaxation 3 minutes']
        : <String>[];

    final videos = <String>[];
    
    if (_hasAny(moodLower, ['anx', 'panic', 'tense'])) {
      videos.addAll([
        'guided box breathing 2 minutes',
        '4-7-8 breathing technique meditation',
        'anxiety relief grounding exercise',
        'calm your nervous system meditation',
        'quick anxiety reset meditation',
        ...extraVideos,
      ]);
    } else if (_hasAny(moodLower, ['sad', 'low', 'down'])) {
      videos.addAll([
        'uplifting nature scenes 2 minutes',
        'mood boost visualization meditation',
        'gratitude meditation short',
        'feel good affirmations video',
        'happy peaceful nature video',
        ...extraVideos,
      ]);
    } else if (_hasAny(moodLower, ['overwhelm', 'stress'])) {
      videos.addAll([
        'stress relief meditation 3 minutes',
        'calm visualization exercise',
        'progressive muscle relaxation short',
        'grounding meditation for overwhelm',
        'peaceful nature meditation',
        ...extraVideos,
      ]);
    } else {
      videos.addAll([
        'mindfulness meditation 2 minutes',
        'calming nature scenes',
        'peaceful breathing exercise',
        'gentle relaxation video',
        'quiet meditation practice',
        ...extraVideos,
      ]);
    }
    
    final videoQuery = videos[variationIndex % videos.length];
    final suggestion = 'On your $device, watch a $videoQuery video and follow along.';
    final link = _ytSearch(videoQuery);
    
    return SuggestionWithLink(suggestion: suggestion, linkUrl: link);
  }

  // ---------------------------------------------------------------------------
  // EXERCISE SUGGESTION (now pattern-aware + anti-repetition)
  // ---------------------------------------------------------------------------

  static Future<SuggestionWithLink> _generateExerciseSuggestion({
    required String mood,
    required List<String> items,
    required Map<String, String> prefs,
    required int variationIndex,
    required MoodInsight insight,
    String? apiKey,
  }) async {
    final item = items.isNotEmpty ? items.first : 'something nearby';
    final moodLower = mood.toLowerCase();
    
    final exercises = <String>[];
    
    if (_hasAny(moodLower, ['anx', 'panic', 'tense'])) {
      exercises.addAll([
        'Hold the $item and count 10 slow breaths, focusing only on the exhale.',
        'Trace the outline of the $item with your finger for 5 cycles while breathing slowly.',
        'Place the $item in your palm and describe 3 textures you feel, then take 5 deep breaths.',
        'Hold the $item and name 5 things you see, 4 you hear, 3 you can touch.',
        'Press the $item gently between your hands and breathe in for 4, hold for 4, out for 6.',
        // Extra variety driven by pattern awareness
        if (insight.dominantMood != null && insight.moodFrequency[insight.dominantMood] != null &&
            insight.moodFrequency[insight.dominantMood]! > 3)
          'With the $item nearby, write down one thing that made you smile this week, then breathe slowly for 1 minute.',
      ]);
    } else if (_hasAny(moodLower, ['sad', 'low', 'down'])) {
      exercises.addAll([
        'Look at the $item and list 3 memories it reminds you of, then smile.',
        'Hold the $item and think of one person you\'re grateful for while taking 5 deep breaths.',
        'Place the $item somewhere visible and do 10 gentle shoulder rolls.',
        'Touch the $item and say out loud: "This moment is temporary. I am stronger than I feel."',
        'With the $item nearby, write down 3 tiny things that went okay today.',
        if (insight.moodTrend == 'declining')
          'Sit with the $item and place a hand on your heart — say "I\'m doing the best I can" three times.',
      ]);
    } else if (_hasAny(moodLower, ['angry', 'frustrat'])) {
      exercises.addAll([
        'Squeeze the $item tightly for 5 seconds, then release. Repeat 5 times with slow breaths.',
        'Place the $item down firmly, then shake your hands vigorously for 20 seconds.',
        'Hold the $item and tense every muscle for 5 seconds, then release completely.',
        'Put the $item aside, then do 10 jumping jacks and 5 slow breaths.',
        'With the $item in view, clench your jaw, hold for 3 seconds, release. Repeat 5 times.',
      ]);
    } else if (_hasAny(moodLower, ['overwhelm', 'stress'])) {
      exercises.addAll([
        'Set the $item in front of you. Organize or tidy 5 small things nearby, then stop.',
        'Touch the $item and list the smallest next step you can take today. Just one.',
        'Hold the $item and break down your biggest worry into 3 tiny pieces.',
        'With the $item nearby, write "I can only control this moment" 3 times.',
        'Place the $item aside and do a 2-minute brain dump — write every thought, no filter.',
        if (insight.peakCheckInTime == 'late_night')
          'With the $item nearby, list 3 things you will NOT do tonight — give yourself permission to rest.',
      ]);
    } else {
      exercises.addAll([
        'Hold the $item for 1 minute and notice its temperature, weight, and texture.',
        'Place the $item on a surface and tap it gently 10 times while breathing slowly.',
        'With the $item in hand, stretch your arms up high, then relax. Repeat 3 times.',
        'Look at the $item and describe its color in 5 different ways.',
        'Touch the $item and count backwards from 20, taking one breath per number.',
      ]);
    }

    // Anti-repetition: filter out exercises that closely match recent suggestions
    final filtered = _filterRecentlySeen(exercises, insight.recentSuggestions);
    final pool = filtered.isNotEmpty ? filtered : exercises;
    final suggestion = pool[variationIndex % pool.length];
    
    return SuggestionWithLink(suggestion: suggestion, linkUrl: null);
  }

  // ---------------------------------------------------------------------------
  // LEGACY API (backward-compatible)
  // ---------------------------------------------------------------------------

  static Future<String> suggest({
    String? apiKey,
    required String mood,
    required List<String> items,
    String? uid,
    Map<String, String>? userPreferences,
  }) async {
    final crisisCheck = detectCrisis(mood: mood, items: items);
    if (crisisCheck.isCrisis) return _formatCrisisResponse(crisisCheck);
    
    final r = await suggestWithLink(
      apiKey: apiKey,
      mood: mood,
      items: items,
      uid: uid,
      userPreferences: userPreferences,
    );
    return r.suggestion;
  }

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
        : const SuggestionWithLink(suggestion: 'Something went wrong. Please try again.');
  }

  static Future<List<SuggestionWithLink>> suggestBatchWithLinks({
    String? apiKey,
    required String mood,
    required List<String> items,
    String? uid,
    int n = 5,
    int? nonce,
    Map<String, String>? userPreferences,
    MoodInsight? moodInsight,
  }) async {
    n = (n <= 0) ? 1 : (n > 5 ? 5 : n);

    Map<String, dynamic>? prefs;
    
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

    final insight = moodInsight ?? const MoodInsight();
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
      texts = _localSuggestionBatch(
        mood: mood,
        items: items,
        hourBucket: hourBucket,
        energyPreference: energyPref,
        n: n,
        nonce: nonce,
        userPreferences: prefs,
        insight: insight,
      );
    } else {
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
        insight: insight,
      );

      if (texts.isEmpty) {
        texts = _localSuggestionBatch(
          mood: mood,
          items: items,
          hourBucket: hourBucket,
          energyPreference: energyPref,
          n: n,
          nonce: nonce,
          userPreferences: prefs,
          insight: insight,
        );
      }
    }

    texts = texts.map((s) => _ensureItemMention(s, items)).toList();

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
  // ONLINE (OpenAI) — now injects mood pattern context
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
    MoodInsight insight = const MoodInsight(),
  }) async {
    final near = (items.isNotEmpty ? items.join(', ') : 'something nearby');
    final nonceText = (nonce == null) ? '' : '\nNonce: $nonce';

    // Build preferences section
    String prefsContext = '';
    if (userPreferences != null && userPreferences.isNotEmpty) {
      prefsContext = '\n\nUser preferences (incorporate when relevant):';
      if (userPreferences['favoriteSongSad'] != null)
        prefsContext += '\n- Favorite song when sad: ${userPreferences['favoriteSongSad']}';
      if (userPreferences['favoriteSongAnxious'] != null)
        prefsContext += '\n- Favorite song when anxious: ${userPreferences['favoriteSongAnxious']}';
      if (userPreferences['favoritePodcast'] != null)
        prefsContext += '\n- Favorite podcast: ${userPreferences['favoritePodcast']}';
      if (userPreferences['comfortFood'] != null)
        prefsContext += '\n- Comfort food: ${userPreferences['comfortFood']}';
      if (userPreferences['goToActivity'] != null)
        prefsContext += '\n- Go-to activity: ${userPreferences['goToActivity']}';
      if (userPreferences['safeSpace'] != null)
        prefsContext += '\n- Safe space: ${userPreferences['safeSpace']}';
    }

    // Build mood pattern section
    final patternContext = insight.toPromptContext();
    final exclusionHint = insight.toExclusionHint();

    final patternSection = patternContext.isNotEmpty
        ? '\n\nMood pattern insights (use to personalise tone and approach):\n$patternContext'
        : '';

    final exclusionSection = exclusionHint.isNotEmpty
        ? '\n\nAnti-repetition rule:\n$exclusionHint'
        : '';

    final prompt = '''
You are a brief behavioral activation coach. The user gives a feeling and nearby items.
Return EXACTLY $n unique, tiny, safe, highly doable tasks (<= 2 short sentences each).
Output format STRICT: one line per suggestion, each starting with "- " and nothing else.

Rules:
- You MUST reference at least ONE of the provided nearby items BY NAME in EACH task.
- CRITICAL: The action you suggest MUST be physically appropriate for the item.
  - Fixed objects (window, wall, mirror, desk, sink, bed, floor): use them as a backdrop — stand near, lean against, look at, wash at, sit on, lie on. NEVER say "hold the window" or "take the wall in hand".
  - Drinkable items (coffee, tea, water, mug, cup): sip, hold for warmth, smell the steam.
  - Soft items (pillow, blanket, towel): hug, wrap around, press against.
  - Devices (phone, laptop): put down, use the screen for a guided exercise.
  - Graspable small objects (pen, book, bottle, stone): hold, trace, write with.
  - Plants/flowers: look closely at, touch gently.
  - If you are unsure how to use the item physically, describe it visually or use it as a focal point for breathing.
- If input suggests LISTENING (song/music/headphones), prefer a SONG action.
- ONLY suggest a PODCAST when the user explicitly mentions "podcast".
- If input suggests WATCHING, prefer a short video action.
- If the user is HUNGRY, suggest making a quick snack.
- Do NOT name specific song/podcast/video titles unless the user provided them.
- No multiple choices or "or". Each line is one clear action under ~2 minutes.
$prefsContext$patternSection$exclusionSection

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

    final double baseTemp = 0.75;
    final double jitter = (nonce == null) ? 0.0 : ((nonce % 3) - 1) * 0.05;
    // Slightly higher temperature if we detected a declining trend, for more variety
    final double trendBoost = insight.moodTrend == 'declining' ? 0.1 : 0.0;
    final double temp = (baseTemp + jitter + trendBoost).clamp(0.2, 1.1);

    final body = jsonEncode({
      'model': 'gpt-4o-mini',
      'temperature': temp,
      'messages': [
        {
          'role': 'system',
          'content':
              'Return only the requested lines. No extra commentary. Be concrete, compassionate, and safe. '
              'Use user preferences and mood pattern context when relevant to make suggestions feel personal.'
        },
        {'role': 'user', 'content': prompt},
      ],
    });

    try {
      final resp = await http
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode < 200 || resp.statusCode >= 300) return <String>[];

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final choices = data['choices'] as List?;
      final content = (choices != null &&
              choices.isNotEmpty &&
              choices.first is Map &&
              (choices.first as Map)['message'] is Map)
          ? (((choices.first as Map)['message'] as Map)['content'] as String?)
          : null;

      if (content == null || content.trim().isEmpty) return <String>[];

      final lines = content
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.startsWith('- '))
          .map((s) => s.substring(2).trim())
          .where((s) => s.isNotEmpty)
          .toList();

      // Anti-repetition post-filter
      final filtered = _filterRecentlySeen(lines, insight.recentSuggestions);
      final pool = filtered.isNotEmpty ? filtered : lines;

      final seen = <String>{};
      final out = <String>[];
      for (final l in pool) {
        final k = l.toLowerCase();
        if (!seen.contains(k)) {
          seen.add(k);
          out.add(l);
        }
      }
      return out.length > n ? out.sublist(0, n) : out;
    } on TimeoutException {
      return <String>[];
    } catch (_) {
      return <String>[];
    }
  }

  // ---------------------------------------------------------------------------
  // OFFLINE FALLBACK — now pattern-aware
  // ---------------------------------------------------------------------------

  static List<String> _localSuggestionBatch({
    required String mood,
    required List<String> items,
    required String hourBucket,
    required String energyPreference,
    required int n,
    int? nonce,
    Map<String, dynamic>? userPreferences,
    MoodInsight insight = const MoodInsight(),
  }) {
    final base = <String>[];

    final thing = items.isNotEmpty ? items.first.trim() : '';
    if (thing.isNotEmpty && !_isEnabler(thing)) {
      base.addAll(_itemActionVariants(thing));
    } else {
      base.add(_localSuggestion(
        mood,
        items,
        hourBucket: hourBucket,
        energyPreference: energyPreference,
        userPreferences: userPreferences,
      ));
    }

    final m = mood.toLowerCase();

    // Preferences-based additions
    if (userPreferences != null) {
      final hasPhone = items.any((i) => i.toLowerCase().contains('phone'));
      if (hasPhone && _hasAny(m, ['sad', 'low', 'down']) &&
          userPreferences['favoriteSongSad'] != null) {
        base.add('On your phone, play "${userPreferences['favoriteSongSad']}" - your go-to song when feeling low.');
      }
      if (hasPhone && _hasAny(m, ['anx', 'nervous', 'panic', 'tense']) &&
          userPreferences['favoriteSongAnxious'] != null) {
        base.add('On your phone, play "${userPreferences['favoriteSongAnxious']}" - your calming song.');
      }
      if (userPreferences['goToActivity'] != null) {
        base.add('Try ${userPreferences['goToActivity']} for 2 minutes - your go-to activity.');
      }
    }

    // Pattern-based additions
    if (insight.moodTrend == 'declining' && thing.isNotEmpty) {
      base.add('Hold the $thing and say quietly: "I\'ve been through hard days before. I can do this."');
    }
    if (insight.dominantMood != null &&
        insight.moodFrequency[insight.dominantMood] != null &&
        insight.moodFrequency[insight.dominantMood]! > 4) {
      // They've been in this mood a lot — suggest something slightly different
      base.add('Try something different: stand up, stretch for 30 seconds, then look out a window.');
    }
    if (insight.peakCheckInTime == 'late_night' && _hasAny(m, ['anx', 'stress'])) {
      base.add('Before sleeping, write tomorrow\'s ONE task on paper and put it away. Your mind can rest now.');
    }

    // Mood-based pool
    if (_hasAny(m, ['hungry', 'hangry', 'starv', 'snack', 'food', 'eat'])) {
      base.addAll([
        'Open a 5-minute snack recipe and prepare just the first step.',
        'Fill a glass of water and eat a small snack while taking five slow breaths.',
      ]);
    } else if (_wantsListen(userText: m) || thing.contains('headphone') || _isEnabler(thing)) {
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
        'Open your photos and favourite the first picture that makes you smile.',
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
    } else {
      base.addAll([
        if (thing.isNotEmpty)
          'Name one feeling out loud, then hold the $thing while counting 10 slow breaths.',
        'Look around and name three colors you see, then breathe slowly.',
      ]);
    }

    if (nonce != null && base.length > 1) {
      final k = nonce.abs() % base.length;
      final rotated = [...base.sublist(k), ...base.sublist(0, k)];
      base..clear()..addAll(rotated);
    }

    // Anti-repetition filter
    final filtered = _filterRecentlySeen(base, insight.recentSuggestions);
    final pool = filtered.length >= n ? filtered : base;

    final seen = <String>{};
    final out = <String>[];
    for (final s in pool) {
      final k = s.toLowerCase();
      if (!seen.contains(k)) {
        seen.add(k);
        out.add(s);
      }
      if (out.length >= n) break;
    }

    while (out.length < n) {
      out.add('Take five slow breaths and relax your shoulders.');
    }

    return out.map((s) => _ensureItemMention(s, items)).toList();
  }

  static String _localSuggestion(
    String mood,
    List<String> items, {
    required String hourBucket,
    required String energyPreference,
    Map<String, dynamic>? userPreferences,
  }) {
    final thing = items.isNotEmpty ? items.first : 'something nearby';
    final m = mood.toLowerCase();

    final hasPhone = items.any((i) => i.toLowerCase().contains('phone'));
    if (hasPhone && userPreferences != null) {
      if (_hasAny(m, ['sad', 'low', 'down']) && userPreferences['favoriteSongSad'] != null) {
        return 'On your phone, play "${userPreferences['favoriteSongSad']}" - your go-to song when feeling low.';
      }
      if (_hasAny(m, ['anx', 'nervous', 'panic', 'tense']) && userPreferences['favoriteSongAnxious'] != null) {
        return 'On your phone, play "${userPreferences['favoriteSongAnxious']}" - your calming song.';
      }
    }

    if (_hasAny(m, ['hungry', 'hangry', 'starv', 'snack', 'food', 'eat'])) {
      return 'Open a quick 5-minute recipe and make a small snack.';
    }

    if (_wantsListen(userText: mood)) {
      if (m.contains('podcast')) return 'Press play on a short uplifting podcast for a minute.';
      return energyPreference == 'gentle' || hourBucket == 'late_night'
          ? 'Put on a calm song for one minute and breathe with the rhythm.'
          : 'Put on your headphones and play a song that fits your mood for one minute.';
    }

    if (_wantsWatch(userText: mood)) {
      return hourBucket == 'late_night'
          ? 'Watch a cozy, quiet clip for one minute with the volume low, then notice your breath.'
          : 'Watch a short uplifting clip for one minute and notice one thing that makes you smile.';
    }

    if (_hasAny(m, ['anx', 'nervous', 'panic', 'tense'])) {
      return 'Hold the $thing and trace its outline for 5 slow breaths. Whisper one calming word on each exhale.';
    }
    if (_hasAny(m, ['low', 'sad', 'down'])) {
      return energyPreference == 'gentle' || hourBucket == 'late_night'
          ? 'Play a calm song for one minute and breathe with the rhythm.'
          : 'Play a feel-good song for one minute and gently sway to the beat.';
    }
    if (_hasAny(m, ['overwhelm', 'stress'])) {
      return 'Set a 60-second timer. Tidy or stack 5 small items near you, then stop. Say "good enough."';
    }
    if (_hasAny(m, ['angry', 'frustrat', 'irritat', 'mad'])) {
      return 'Unclench your jaw and drop your shoulders. Take 10 slow breaths while lightly squeezing the $thing.';
    }
    if (_hasAny(m, ['exhaust', 'tired', 'drained', 'sleepy', 'wiped'])) {
      return energyPreference == 'gentle'
          ? 'Lie back or sit tall and take 6 slow breaths while you lightly stretch your neck and shoulders.'
          : 'Stand up, roll your shoulders, and take 6 slow breaths while stretching your neck.';
    }
    if (_hasAny(m, ['stuck', 'no motivation', 'procrast'])) {
      return 'Stand up and touch the nearest wall for 10 seconds. One tiny step counts.';
    }
    return energyPreference == 'gentle' || hourBucket == 'late_night'
        ? 'Name one feeling out loud, then hold the $thing for one quiet minute while counting 10 slow breaths.'
        : 'Name one feeling out loud, then interact with the $thing for one minute while counting 10 slow breaths.';
  }

  // ---------------------------------------------------------------------------
  // ANTI-REPETITION HELPER
  // ---------------------------------------------------------------------------

  /// Removes suggestions that closely resemble anything in [recentSuggestions].
  static List<String> _filterRecentlySeen(
      List<String> candidates, List<String> recentSuggestions) {
    if (recentSuggestions.isEmpty) return candidates;

    // Build a set of "key phrase" trigrams from recent suggestions
    final recentKeys = recentSuggestions
        .expand((s) => _ngrams(s.toLowerCase(), 4))
        .toSet();

    return candidates.where((candidate) {
      final candKeys = _ngrams(candidate.toLowerCase(), 4).toSet();
      final overlap = candKeys.intersection(recentKeys).length;
      // If more than 2 four-word phrases overlap, consider it too similar
      return overlap < 3;
    }).toList();
  }

  /// Generates all n-grams (word-level) of length [n] from [text].
  static List<String> _ngrams(String text, int n) {
    final words = text.split(RegExp(r'\s+'));
    if (words.length < n) return [text];
    final out = <String>[];
    for (int i = 0; i <= words.length - n; i++) {
      out.add(words.sublist(i, i + n).join(' '));
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // LINK LOGIC (unchanged)
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
        itemsText.contains('speaker');

    final explicitPodcast = RegExp(r'\bpodcasts?\b').hasMatch(text);
    final explicitSong = RegExp(r'\b(song|music|playlist)\b').hasMatch(text);
    final wantsWatch = _wantsWatch(userText: text);

    final preferPodcast = explicitPodcast && !explicitSong;
    final preferSong = explicitSong || (hasHeadphones && !preferPodcast);

    final cat = _classifyMood(userText);

    if (cat == _MoodCat.hungry) {
      return _webSearch('quick easy 5 minute recipe healthy snack');
    }

    if (preferSong) {
      switch (cat) {
        case _MoodCat.anxious:
          return _prefOrSearch(
            prefs?['favoriteSongAnxious'] as String? ?? prefs?['calmSong'] as String?,
            fallback: 'calming instrumental song 2 minutes',
            defaultService: defaultMusicService,
          );
        case _MoodCat.low:
          return _prefOrSearch(
            prefs?['favoriteSongSad'] as String? ?? prefs?['happySong'] as String?,
            fallback: 'feel good song quick mood boost',
            defaultService: defaultMusicService,
          );
        case _MoodCat.angry:
          return _prefOrSearch(prefs?['energizeSong'] as String?,
              fallback: 'energetic clean song quick motivation',
              defaultService: defaultMusicService);
        case _MoodCat.exhausted:
          return _prefOrSearch(prefs?['energizeSong'] as String?,
              fallback: 'gentle motivational song 2 minutes',
              defaultService: defaultMusicService);
        case _MoodCat.overwhelmed:
          final genre = (prefs?['focusGenre'] as String?)?.trim();
          return _musicSearch(
              '${(genre?.isNotEmpty == true) ? '$genre ' : ''}lofi focus 2 minutes',
              defaultService: defaultMusicService);
        case _MoodCat.stuck:
          return _musicSearch('upbeat get moving song 1 minute',
              defaultService: defaultMusicService);
        case _MoodCat.happy:
          return _prefOrSearch(prefs?['happySong'] as String?,
              fallback: 'happy upbeat song', defaultService: defaultMusicService);
        default:
          return _musicSearch('feel good song 1 minute', defaultService: defaultMusicService);
      }
    }

    if (preferPodcast) {
      final fav = (prefs?['favoritePodcast'] as String?)?.trim();
      return (fav != null && fav.isNotEmpty)
          ? _mediaLinkFromPref(fav,
              fallbackQuery: 'short uplifting podcast 5 minutes',
              defaultService: defaultMusicService)
          : _ytSearch('short uplifting podcast 5 minutes');
    }

    if (wantsWatch) {
      switch (cat) {
        case _MoodCat.anxious:
          return _ytSearch('guided box breathing 2 minutes');
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
        default:
          return _ytSearch('short wholesome clip 2 minutes');
      }
    }

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
    if (v.isEmpty) return _musicSearch(fallback, defaultService: defaultService);
    return _mediaLinkFromPref(v, fallbackQuery: fallback, defaultService: defaultService);
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
    if (_hasAny(t, ['hungry', 'hangry', 'starv', 'snack', 'food', 'eat'])) return _MoodCat.hungry;
    if (_hasAny(t, ['anx', 'nervous', 'panic', 'tense'])) return _MoodCat.anxious;
    if (_hasAny(t, ['angry', 'mad', 'frustrat', 'irritat'])) return _MoodCat.angry;
    if (_hasAny(t, ['exhaust', 'tired', 'drained', 'sleepy', 'wiped'])) return _MoodCat.exhausted;
    if (_hasAny(t, ['overwhelm', 'stress'])) return _MoodCat.overwhelmed;
    if (_hasAny(t, ['stuck', 'no motivation', 'procrast'])) return _MoodCat.stuck;
    if (_hasAny(t, ['low', 'sad', 'down', 'blue'])) return _MoodCat.low;
    if (_hasAny(t, ['happy', 'good', 'excited'])) return _MoodCat.happy;
    return _MoodCat.neutral;
  }

  static bool _wantsListen({required String userText}) {
    final t = userText.toLowerCase();
    return t.contains('listen') || t.contains('song') || t.contains('music') ||
        t.contains('playlist') || t.contains('headphone') || t.contains('earbud') ||
        t.contains('airpod') || t.contains('speaker') || t.contains('podcast');
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
    return t.contains('phone') || t.contains('headphone') ||
        t.contains('earbud') || t.contains('airpod') || t.contains('speaker');
  }

  static List<String> _itemActionVariants(String itemRaw) {
    final item = itemRaw.toLowerCase().trim();

    // Helper: replaces literal \$item with the actual item name
    List<String> v(List<String> lines) =>
        lines.map((l) => l.replaceAll(r'$item', itemRaw)).toList();

    // --- Fixed / structural (you stand near, look at, or interact with) ---
    if (_hasAny(item, ['window'])) return v([
      'Stand by the \$item and find 3 things you can see outside. Name each one slowly.',
      'Look through the \$item and take 6 deep breaths, watching the world outside for one minute.',
    ]);
    if (_hasAny(item, ['mirror'])) return v([
      'Look in the \$item, take a slow breath, and say one kind thing to yourself out loud.',
      'Stand before the \$item and roll your shoulders back 5 times while breathing slowly.',
    ]);
    if (_hasAny(item, ['wall'])) return v([
      'Place both palms flat on the \$item, press gently for 5 seconds, then release. Repeat 4 times.',
      'Lean your back against the \$item, close your eyes, and take 8 slow breaths.',
    ]);
    if (_hasAny(item, ['door'])) return v([
      'Hold the handle of the \$item and take 5 slow breaths before opening it as a small reset.',
      'Step through the \$item into a different room for 60 seconds to change your surroundings.',
    ]);
    if (_hasAny(item, ['sink'])) return v([
      'Go to the \$item and run cool water over your wrists for 30 seconds, breathing slowly.',
      'Wash your hands slowly at the \$item, focusing only on the temperature and sound of the water.',
    ]);
    if (_hasAny(item, ['stove', 'oven', 'kettle'])) return v([
      'Step away from the \$item and make a warm drink — hold the mug and breathe in the steam.',
      'Near the \$item, set a timer for 2 minutes and focus only on the simple task in front of you.',
    ]);
    if (_hasAny(item, ['desk', 'table', 'counter'])) return v([
      'Rest your forearms on the \$item and take 6 slow grounding breaths.',
      'Tap the surface of the \$item slowly with your fingertips — 10 taps per hand — focusing on the sensation.',
    ]);
    if (_hasAny(item, ['shelf', 'bookshelf'])) return v([
      'Look at the \$item and pick one object on it to describe in detail while breathing slowly.',
    ]);
    if (_hasAny(item, ['fridge', 'refrigerator'])) return v([
      'Open the \$item, pour yourself a glass of cold water, and drink it slowly with 5 pauses.',
    ]);

    // --- Seating / lying surfaces ---
    if (_hasAny(item, ['bed'])) return v([
      'Lie back on the \$item with your hands on your belly and breathe deeply for 2 minutes.',
      'Sit on the edge of the \$item, roll your shoulders 5 times, and stretch your neck side to side.',
    ]);
    if (_hasAny(item, ['couch', 'sofa'])) return v([
      'Sit on the \$item and pull your knees to your chest for 30 seconds, then slowly stretch out.',
      'Lean into the \$item, close your eyes, and list 5 sounds you can hear right now.',
    ]);
    if (_hasAny(item, ['chair'])) return v([
      'Sit tall in the \$item, plant your feet flat on the floor, and take 8 slow belly breaths.',
      'While seated in the \$item, squeeze and release your hands 10 times to release tension.',
    ]);
    if (_hasAny(item, ['floor', 'mat', 'rug', 'carpet'])) return v([
      'Sit on the \$item and do a quick body scan — notice where you hold tension and relax it.',
      'Stretch out on the \$item for 2 minutes, lengthening your spine with each exhale.',
    ]);

    // --- Warm / drinkable ---
    if (_hasAny(item, ['coffee', 'tea', 'mug', 'cup'])) return v([
      'Wrap both hands around your \$item, feel the warmth, and take 5 slow sips with a breath between each.',
      'Hold the \$item close and breathe in the aroma slowly for a full minute.',
    ]);
    if (_hasAny(item, ['water', 'bottle', 'glass', 'drink', 'juice'])) return v([
      'Drink your \$item slowly — 5 small sips, pausing to notice the coolness and breathe.',
      'Hold the \$item with both hands and take 6 slow breaths before you drink anything.',
    ]);

    // --- Nature / living ---
    if (_hasAny(item, ['plant', 'succulent', 'cactus', 'flower', 'herb'])) return v([
      'Look closely at the \$item and count 5 different shades or textures you can see. Breathe slowly.',
      'Gently touch the leaves of the \$item and take 6 breaths, noticing the texture.',
    ]);

    // --- Writing / paper ---
    if (_hasAny(item, ['pen', 'pencil', 'marker'])) return v([
      'Pick up the \$item and write one kind sentence to yourself on any nearby paper. Read it aloud.',
      'Hold the \$item and tap it gently on your palm 10 times as a grounding reset.',
    ]);
    if (_hasAny(item, ['notebook', 'journal', 'diary'])) return v([
      'Open the \$item and write down 3 words that describe how you feel right now. No filtering.',
      'Flip to a blank page in the \$item and write one thing you are grateful for. Breathe slowly.',
    ]);
    if (_hasAny(item, ['book'])) return v([
      'Open the \$item to any page and read 3 sentences out loud, slowly.',
      'Hold the \$item and scan the cover for 30 seconds while breathing in for 4, out for 6.',
    ]);

    // --- Soft / comforting ---
    if (_hasAny(item, ['pillow'])) return v([
      'Hug the \$item firmly and take 6 slow breaths, letting your shoulders drop on each exhale.',
      'Press your face gently into the \$item for 30 seconds and breathe.',
    ]);
    if (_hasAny(item, ['blanket', 'duvet', 'comforter'])) return v([
      'Wrap the \$item around your shoulders and sit quietly for 2 minutes, breathing slowly.',
      'Rub a corner of the \$item between your fingers as a grounding texture exercise.',
    ]);
    if (_hasAny(item, ['towel'])) return v([
      'Hold the \$item and press it firmly between your palms for 5 seconds, release, and breathe.',
    ]);
    if (_hasAny(item, ['stuffed', 'teddy', 'plush', 'toy'])) return v([
      'Hold your \$item and give it a squeeze. Take 5 slow breaths, noticing the softness.',
    ]);

    // --- Sensory / scent ---
    if (_hasAny(item, ['candle'])) return v([
      'Light the \$item safely and watch the flame for one minute, breathing in for 4 and out for 6.',
      'Hold the unlit \$item near your nose and take 6 long slow breaths, focusing on the scent.',
    ]);
    if (_hasAny(item, ['diffuser', 'essential oil', 'perfume', 'lotion', 'cream'])) return v([
      'Apply or smell the \$item and take 6 long, slow breaths, focusing only on the scent.',
    ]);

    // --- Devices / screens ---
    if (_hasAny(item, ['phone', 'mobile', 'smartphone'])) return v([
      'Put your \$item face-down and leave it for 2 minutes — just breathe. You can check it after.',
      'Use your \$item to play a 2-minute breathing guide and follow along with your eyes closed.',
    ]);
    if (_hasAny(item, ['laptop', 'computer', 'pc'])) return v([
      'Minimize everything on your \$item, set a 2-minute timer, and do nothing but breathe.',
      'Step back from your \$item for 2 minutes, look away, and do a slow neck and shoulder stretch.',
    ]);
    if (_hasAny(item, ['headphone', 'earbud', 'airpod', 'speaker'])) return v([
      'Put on your \$item and play one calming song from start to finish without doing anything else.',
      'Put your \$item in and listen to 2 minutes of gentle music or nature sounds with your eyes closed.',
    ]);
    if (_hasAny(item, ['tv', 'television', 'screen', 'monitor'])) return v([
      'Turn off the \$item for 2 minutes and sit quietly in the silence, noticing your breath.',
    ]);

    // --- Generic graspable fallback for anything small and holdable ---
    return v([
      'Pick up the \$item, hold it gently, and count 10 slow breaths focusing on how it feels in your hands.',
      'Set the \$item in front of you and describe it out loud — shape, color, texture — while breathing slowly.',
    ]);
  }

  static String _ensureItemMention(String text, List<String> items) {
    if (items.isEmpty) return text;
    if (_mentionsAny(text, items)) return text;
    final item = items.first.trim();
    if (item.isEmpty) return text;
    String lowerFirst(String s) => s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);
    // Use a physically appropriate prefix based on what the item actually is
    final prefix = _itemContextPrefix(item);
    return '$prefix ${lowerFirst(text)}';
  }

  /// Returns a grammatically and physically sensible lead-in phrase for the item.
  /// e.g. a window → "Standing by the window," not "With the window in hand,"
  static String _itemContextPrefix(String itemRaw) {
    final t = itemRaw.toLowerCase().trim();

    // --- Fixed/structural things you stand near or look at ---
    if (_hasAny(t, ['window', 'door', 'wall', 'mirror', 'fireplace', 'stove', 'sink', 'fridge', 'shelf', 'desk', 'table', 'counter'])) {
      return 'Standing near the $itemRaw,';
    }

    // --- Things you sit or lie on ---
    if (_hasAny(t, ['bed', 'couch', 'sofa', 'chair', 'floor', 'mat', 'rug', 'carpet'])) {
      return 'Sitting on the $itemRaw,';
    }

    // --- Screens / devices you look at ---
    if (_hasAny(t, ['tv', 'television', 'screen', 'monitor', 'laptop', 'computer', 'ipad', 'tablet'])) {
      return 'With your $itemRaw nearby,';
    }

    // --- Things you wear ---
    if (_hasAny(t, ['headphone', 'earbud', 'airpod', 'glasses', 'watch', 'jacket', 'hoodie', 'sweater'])) {
      return 'With your $itemRaw on,';
    }

    // --- Drinkable things ---
    if (_hasAny(t, ['coffee', 'tea', 'water', 'juice', 'drink', 'mug', 'cup', 'glass', 'bottle'])) {
      return 'With your $itemRaw in hand,';
    }

    // --- Plants, nature objects ---
    if (_hasAny(t, ['plant', 'flower', 'tree', 'leaf', 'succulent', 'cactus'])) {
      return 'Looking at the $itemRaw,';
    }

    // --- Handheld / graspable everyday objects ---
    if (_hasAny(t, ['pen', 'pencil', 'marker', 'phone', 'book', 'notebook', 'journal', 'pillow',
        'blanket', 'towel', 'candle', 'remote', 'keys', 'wallet', 'bag', 'ball', 'toy',
        'stone', 'rock', 'crystal', 'fidget', 'stress ball', 'coin', 'ring', 'bracelet',
        'rubber band', 'clip', 'stapler', 'eraser', 'tape', 'brush', 'comb'])) {
      return 'With the $itemRaw in hand,';
    }

    // --- Food items ---
    if (_hasAny(t, ['apple', 'banana', 'snack', 'fruit', 'cracker', 'chip', 'chocolate', 'gum'])) {
      return 'With a $itemRaw nearby,';
    }

    // Default: safe generic fallback that avoids "in hand" for unknown items
    return 'Near the $itemRaw,';
  }

  static bool _mentionsAny(String text, List<String> items) {
    final t = text.toLowerCase();
    for (final raw in items) {
      final w = raw.trim().toLowerCase();
      if (w.isEmpty) continue;
      if (RegExp(r'(^|[^a-z])' + RegExp.escape(w) + r'([^a-z]|$)').hasMatch(t)) return true;
    }
    return false;
  }

  static String _musicSearch(String q, {String? defaultService}) {
    final svc = (defaultService ?? '').toLowerCase();
    if (svc == 'spotify') return 'https://open.spotify.com/search/${Uri.encodeComponent(q)}';
    if (svc == 'apple') return 'https://music.apple.com/search?term=${Uri.encodeComponent(q)}';
    return _ytSearch(q);
  }

  static String _ytSearch(String q) =>
      'https://www.youtube.com/results?search_query=${Uri.encodeComponent(q)}';

  static String _webSearch(String q) =>
      'https://www.google.com/search?q=${Uri.encodeComponent(q)}';

  static String _mediaLinkFromPref(String? value,
      {String? fallbackQuery, String? defaultService}) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return _musicSearch(fallbackQuery ?? 'feel good song quick boost', defaultService: defaultService);
    if (_looksLikeUrl(v)) return v;
    return _musicSearch(v, defaultService: defaultService);
  }

  static bool _looksLikeUrl(String s) {
    final t = s.toLowerCase();
    return t.startsWith('http://') || t.startsWith('https://') ||
        t.startsWith('youtu.be/') || t.startsWith('open.spotify.com/') ||
        t.startsWith('music.apple.com/');
  }

  static String _hourBucket(DateTime now) {
    final h = now.hour;
    if (h >= 5 && h < 12) return 'morning';
    if (h >= 12 && h < 17) return 'afternoon';
    if (h >= 17 && h < 22) return 'evening';
    return 'late_night';
  }
}