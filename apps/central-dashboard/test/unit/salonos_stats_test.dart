import 'package:centralny_dashboard/features/salonos/models/salonos_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the canonical SALONOS V1 response', () {
    final stats = SalonosStats.fromJson({
      'provider': {
        'id': 'provider-1',
        'businessName': 'Example Services',
        'businessType': 'HOME_SERVICES',
      },
      'totalAiRevenue': 2740,
      'breakdown': {
        'returnEngine': 1420,
        'slotFiller': 820,
        'noShowGuards': 500,
      },
      'dailyActions': [
        {
          'id': 'return-engine',
          'title': 'Osloviť klientov',
          'detail': 'Klienti po termíne návratu.',
          'count': 12,
        },
      ],
      'currency': 'EUR',
      'periodStart': '2026-08-01T00:00:00.000Z',
    });

    expect(stats.providerId, 'provider-1');
    expect(stats.businessType, BusinessType.homeServices);
    expect(stats.totalAiRevenue, 2740);
    expect(stats.breakdown.slotFiller, 820);
    expect(stats.dailyActions.single.count, 12);
    expect(stats.isEmpty, isFalse);
  });

  test('recognizes a canonical empty response', () {
    final stats = SalonosStats.fromJson({
      'provider': {
        'id': 'provider-1',
        'businessName': 'Empty Services',
        'businessType': 'OTHER',
      },
      'totalAiRevenue': 0,
      'breakdown': {'returnEngine': 0, 'slotFiller': 0, 'noShowGuards': 0},
      'dailyActions': const [],
      'currency': 'EUR',
      'periodStart': '2026-08-01T00:00:00.000Z',
    });

    expect(stats.isEmpty, isTrue);
  });

  test('rejects an unsupported business type', () {
    expect(
      () => BusinessType.fromJson('RESTAURANT'),
      throwsA(isA<FormatException>()),
    );
  });
}
