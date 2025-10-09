// lib/utils/media_link.dart
/// Builds a sensible media link when the suggestion implies watching or listening.
/// We return a YouTube search URL so it works on web & mobile without extra APIs.
Uri? mediaLinkFor(String suggestion) {
  final s = suggestion.toLowerCase();

  final isWatch = s.contains('watch') || s.contains('video') || s.contains('clip');
  final isListen = s.contains('listen') || s.contains('music') || s.contains('song') ||
      s.contains('audio') || s.contains('podcast');

  if (!(isWatch || isListen)) return null;

  final tags = <String>[];
  void tag(String key, String as) {
    if (s.contains(key)) tags.add(as);
  }

  // Pick up intent words to make the search nicer.
  tag('uplift', 'uplifting');
  tag('funny', 'funny');
  tag('calm', 'calming');
  tag('relax', 'relaxing');
  tag('focus', 'focus');
  tag('nature', 'nature');
  tag('lofi', 'lofi');
  tag('breath', 'breathing');

  final base = tags.isEmpty
      ? (isWatch ? 'uplifting short video' : 'calming music')
      : tags.join(' ');

  final query = isWatch ? '$base 2 minutes' : '$base 2 minute audio';
  final url =
      'https://www.youtube.com/results?search_query=${Uri.encodeComponent(query)}';
  return Uri.parse(url);
}
