import 'package:centralny_dashboard/features/crm/utils/lead_report_splitter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const splitter = LeadReportSplitter();

  test('keeps short single-lead reports intact', () {
    const text = '''
LEAD 1 — Acme
Contact: Jane
Email: jane@acme.example
''';
    expect(splitter.split(text), [text.trim()]);
  });

  test('packs at most 3 LEAD blocks per chunk', () {
    final buffer = StringBuffer();
    for (var i = 1; i <= 7; i++) {
      buffer.writeln('LEAD $i — Company $i');
      buffer.writeln('Contact: Person $i');
      buffer.writeln('Email: p$i@example.com');
      buffer.writeln();
    }
    final chunks = splitter.split(buffer.toString());
    expect(chunks.length, greaterThanOrEqualTo(3));
    for (final chunk in chunks) {
      final markers = RegExp(
        r'^\s*LEAD\s+\d+',
        multiLine: true,
        caseSensitive: false,
      ).allMatches(chunk).length;
      expect(markers, lessThanOrEqualTo(3));
    }
    expect(splitter.countLeadMarkers(buffer.toString()), 7);
  });

  test('hard-slices oversized section under max chunk length', () {
    final hugeLead = StringBuffer('LEAD 1 — Huge Co\n');
    while (hugeLead.length < 12_000) {
      hugeLead.writeln('detail line ${hugeLead.length}');
    }
    final chunks = splitter.split(hugeLead.toString());
    expect(chunks.length, greaterThan(1));
    for (final chunk in chunks) {
      expect(chunk.length, lessThanOrEqualTo(5000));
    }
  });
}
