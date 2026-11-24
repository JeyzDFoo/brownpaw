import 'package:flutter/foundation.dart';

/// Named sections from a BC Whitewater page's text, keyed in lower case:
/// "gauge and levels", "scenery", "length of run", "length of shuttle",
/// "special considerations", "directions", "description", and so on.
///
/// The pages write each section as a heading line followed by a line
/// starting with ": " (or "(one way): ").
Map<String, String> guideSections(String? fullText) {
  if (fullText == null || fullText.isEmpty) return const {};
  final lines = fullText.split('\n');
  final sections = <String, String>{};
  for (var i = 0; i + 1 < lines.length; i++) {
    final heading = lines[i].trim();
    final next = lines[i + 1];
    final m = RegExp(r'^(\([^)]*\))?\s*:\s*(.*)$').firstMatch(next);
    if (m == null || heading.isEmpty || heading.length > 40) continue;
    if (!RegExp(r'^[A-Z]').hasMatch(heading)) continue;
    final body = m[2]!.trim();
    if (body.isEmpty) continue;
    sections.putIfAbsent(heading.toLowerCase(), () => body);
  }
  return sections;
}

/// A link that opens driving directions to a point in the platform's maps
/// app: Apple Maps on iOS and macOS, Google Maps everywhere else.
Uri directionsUri(
  double latitude,
  double longitude, {
  TargetPlatform? platform,
}) {
  final p = platform ?? defaultTargetPlatform;
  if (!kIsWeb && (p == TargetPlatform.iOS || p == TargetPlatform.macOS)) {
    return Uri.https('maps.apple.com', '/', {
      'daddr': '$latitude,$longitude',
      'dirflg': 'd',
    });
  }
  return Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': '$latitude,$longitude',
  });
}
