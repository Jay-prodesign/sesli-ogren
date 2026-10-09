typedef SourceTextRange = ({int start, int end});

String foldTurkishSourceText(String value) =>
    value.replaceAll('I', 'i').replaceAll('ı', 'i').toLowerCase().replaceAll('\u0307', '');

/// Finds literal source spans using the same Turkish-safe folding as Reader
/// search while returning offsets into the original UTF-16 Dart string.
///
/// The returned text always comes from [source]; this helper never manufactures
/// or semantically infers evidence.
List<SourceTextRange> findTurkishSourceTextMatches(
  String source,
  String query, {
  int limit = 2000,
}) {
  final needle = foldTurkishSourceText(query.trim());
  if (needle.isEmpty || source.isEmpty || limit <= 0) return const [];

  final foldedBuffer = StringBuffer();
  final foldedStarts = <int>[];
  final foldedEnds = <int>[];
  var sourceOffset = 0;
  for (final rune in source.runes) {
    final original = String.fromCharCode(rune);
    final folded = foldTurkishSourceText(original);
    foldedBuffer.write(folded);
    for (var unit = 0; unit < folded.length; unit++) {
      foldedStarts.add(sourceOffset);
      foldedEnds.add(sourceOffset + original.length);
    }
    sourceOffset += original.length;
  }

  final foldedSource = foldedBuffer.toString();
  final matches = <SourceTextRange>[];
  var from = 0;
  while (from < foldedSource.length && matches.length < limit) {
    final at = foldedSource.indexOf(needle, from);
    if (at < 0) break;
    final foldedEnd = at + needle.length - 1;
    if (at < foldedStarts.length && foldedEnd < foldedEnds.length) {
      matches.add((start: foldedStarts[at], end: foldedEnds[foldedEnd]));
    }
    from = at + needle.length;
  }
  return matches;
}

SourceTextRange? findFirstTurkishSourceTextMatch(String source, String query) {
  final matches = findTurkishSourceTextMatches(source, query, limit: 1);
  return matches.isEmpty ? null : matches.first;
}
