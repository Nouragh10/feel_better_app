// lib/services/openai_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenAIService {
  /// Returns a short, *doable* action suggestion.
  /// If [apiKey] is null/empty, falls back to an offline/local suggestion.
  static Future<String> suggest({
    String? apiKey,
    required String mood,
    required List<String> items,
  }) async {
    // Offline/local fallback (no key or web build without key)
    if (apiKey == null || apiKey.isEmpty) {
      return _localSuggestion(mood, items);
    }

    // Online path — call OpenAI (note: exposing keys in web builds is NOT safe for production)
    final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    final near = (items.isNotEmpty ? items.join(', ') : 'something nearby');
    final prompt = '''
You are a brief behavioral activation coach. The user will give a feeling and items nearby.
Return ONE tiny, safe, highly doable task (<= 2 sentences). No disclaimers. Avoid medical claims.
Use the nearby item(s) if possible. Prefer actions under 2 minutes.

Feeling: "$mood"
Nearby: "$near"
''';

    final body = jsonEncode({
      'model': 'gpt-4o-mini',
      'temperature': 0.7,
      'messages': [
        {
          'role': 'system',
          'content':
              'You return one tiny, safe action in 1–2 sentences. Be concrete, compassionate, and doable in under 2 minutes.'
        },
        {'role': 'user', 'content': prompt},
      ],
    });

    try {
      final resp = await http
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 15));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final choices = data['choices'] as List?;
        final msg = choices != null &&
                choices.isNotEmpty &&
                choices.first['message'] != null
            ? (choices.first['message']['content'] as String?)?.trim()
            : null;

        if (msg != null && msg.isNotEmpty) {
          return _sanitize(msg);
        }
        return _localSuggestion(mood, items);
      } else {
        // Network/API error -> safe fallback
        return _localSuggestion(mood, items);
      }
    } on TimeoutException {
      return 'Network timeout—try again in a moment.';
    } catch (_) {
      return _localSuggestion(mood, items);
    }
  }

  // ------------------------- Helpers -------------------------

  static String _sanitize(String s) {
    // Trim, collapse whitespace, ensure single line-ish suggestion
    final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Keep it short
    return t.length > 240 ? '${t.substring(0, 240)}…' : t;
    }

  static String _localSuggestion(String mood, List<String> items) {
    final thing = items.isNotEmpty ? items.first : 'something nearby';
    final m = mood.toLowerCase();

    // Simple, doable “grounding” / activation style actions
    if (m.contains('anx') || m.contains('tense') || m.contains('panic')) {
      return 'Hold the $thing and trace its outline with a finger for 5 slow breaths. Whisper one calming word on each exhale.';
    }
    if (m.contains('low') || m.contains('sad') || m.contains('down')) {
      return 'Open a page and write your full name and today’s date. List 3 tiny wins you can do in 2 minutes (water, window, stretch) and do the first now.';
    }
    if (m.contains('overwhelm') || m.contains('stress')) {
      return 'Set a 60-second timer. Tidy or stack 5 small items near you, then stop. Say “good enough” out loud.';
    }
    if (m.contains('angry') || m.contains('frustrat')) {
      return 'Grip the $thing gently and count 10 slow breaths. On each exhale, unclench your jaw and drop your shoulders.';
    }
    if (m.contains('can’t') || m.contains('cannot') || m.contains('stuck')) {
      return 'Write just your name in your notebook, then stand up and touch the nearest wall for 10 seconds. One tiny step counts.';
    }

    // General fallback
    return 'Name one feeling out loud, then interact with the $thing for one minute (touch, look closely, or move it) while counting 10 slow breaths.';
  }
}
