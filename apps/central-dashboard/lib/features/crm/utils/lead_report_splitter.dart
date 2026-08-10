/// Splits a daily lead report into small semantic chunks for Mistral parse.
///
/// Mirrors `splitLeadReport` in `supabase/functions/lead-assistant/index.ts`.
class LeadReportSplitter {
  const LeadReportSplitter({
    this.maxChunkLength = 5000,
    this.maxLeadsPerChunk = 3,
    this.overlap = 400,
  });

  final int maxChunkLength;
  final int maxLeadsPerChunk;
  final int overlap;

  // Use (?:🔥)? — bare 🔥? breaks UTF-16 surrogate matching in Dart RegExp.
  static final RegExp _leadSplit = RegExp(
    r'(?=^\s*(?:🔥)?\s*LEAD\s+\d+)',
    multiLine: true,
    caseSensitive: false,
  );
  static final RegExp _leadStart = RegExp(
    r'^\s*(?:🔥)?\s*LEAD\s+\d+',
    multiLine: true,
    caseSensitive: false,
  );

  List<String> split(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) return const [];

    if (text.length <= maxChunkLength) {
      final markers = _leadStart.allMatches(text).length;
      if (markers <= maxLeadsPerChunk) return [text];
    }

    var sectionList = _sectionsByLeadMarkers(text);
    if (sectionList.length <= 1) {
      sectionList = text
          .split(_leadSplit)
          .where((s) => s.trim().isNotEmpty)
          .toList();
    }
    if (sectionList.length <= 1) {
      sectionList = text
          .split(RegExp(r'\n{2,}'))
          .where((s) => s.trim().isNotEmpty)
          .toList();
    }
    if (sectionList.isEmpty) return [text];

    final chunks = <String>[];
    var current = '';
    var leadCount = 0;

    void flush() {
      final trimmed = current.trim();
      if (trimmed.isNotEmpty) chunks.add(trimmed);
      current = '';
      leadCount = 0;
    }

    for (final section in sectionList) {
      final isLead = _leadStart.hasMatch(section);
      if (section.length > maxChunkLength) {
        flush();
        for (
          var offset = 0;
          offset < section.length;
          offset += maxChunkLength - overlap
        ) {
          final end = (offset + maxChunkLength).clamp(0, section.length);
          final slice = section.substring(offset, end).trim();
          if (slice.isNotEmpty) chunks.add(slice);
          if (end >= section.length) break;
        }
        continue;
      }

      final nextLeadCount = leadCount + (isLead ? 1 : 0);
      if (current.trim().isNotEmpty &&
          (current.length + section.length > maxChunkLength ||
              nextLeadCount > maxLeadsPerChunk)) {
        flush();
      }
      current += section;
      leadCount += isLead ? 1 : 0;
    }
    flush();
    return chunks.isNotEmpty ? chunks : [text];
  }

  int countLeadMarkers(String rawText) =>
      _leadStart.allMatches(rawText).length;

  List<String> _sectionsByLeadMarkers(String text) {
    final matches = _leadStart.allMatches(text).toList();
    if (matches.isEmpty) return const [];
    final parts = <String>[];
    if (matches.first.start > 0) {
      final preamble = text.substring(0, matches.first.start).trim();
      if (preamble.isNotEmpty) parts.add(preamble);
    }
    for (var i = 0; i < matches.length; i++) {
      final start = matches[i].start;
      final end =
          i + 1 < matches.length ? matches[i + 1].start : text.length;
      final slice = text.substring(start, end).trim();
      if (slice.isNotEmpty) parts.add(slice);
    }
    return parts;
  }
}
