import 'dart:async';

import 'package:centralny_dashboard/features/salonos/models/salonos_stats.dart';
import 'package:centralny_dashboard/features/salonos/presentation/salonos_dashboard_page.dart';
import 'package:centralny_dashboard/features/salonos/services/salonos_stats_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSalonosStatsGateway implements SalonosStatsGateway {
  final Future<SalonosStats> result;

  _FakeSalonosStatsGateway(this.result);

  @override
  Future<SalonosStats> fetchStats() => result;

  @override
  void dispose() {}
}

SalonosStats _stats({bool empty = false}) {
  return SalonosStats(
    providerId: 'provider-1',
    businessName: 'Example Services',
    businessType: BusinessType.homeServices,
    totalAiRevenue: empty ? 0 : 1250,
    breakdown: SalonosBreakdown(
      returnEngine: empty ? 0 : 500,
      slotFiller: empty ? 0 : 450,
      noShowGuards: empty ? 0 : 300,
    ),
    dailyActions: empty
        ? const []
        : const [
            SalonosDailyAction(
              id: 'return-engine',
              title: 'Osloviť klientov',
              detail: 'Klienti pripravení na ďalší kontakt.',
              count: 4,
            ),
          ],
    currency: 'EUR',
    periodStart: DateTime.utc(2026, 8),
  );
}

Widget _app(Future<SalonosStats> result) {
  return MaterialApp(
    home: SalonosDashboardPage(service: _FakeSalonosStatsGateway(result)),
  );
}

void main() {
  testWidgets('shows loading while real data is pending', (tester) async {
    final pending = Completer<SalonosStats>();
    await tester.pumpWidget(_app(pending.future));

    expect(find.text('Načítavam reálne SALONOS dáta…'), findsOneWidget);
  });

  testWidgets('shows industry-neutral success data', (tester) async {
    await tester.pumpWidget(_app(Future.value(_stats())));
    await tester.pumpAndSettle();

    expect(find.text('Example Services'), findsAtLeastNWidgets(1));
    expect(find.text('Návrat klientov'), findsOneWidget);
    expect(find.text('Využitá kapacita'), findsOneWidget);
    expect(find.text('PAPI Hair Design'), findsNothing);
  });

  testWidgets('shows an honest empty state', (tester) async {
    await tester.pumpWidget(_app(Future.value(_stats(empty: true))));
    await tester.pumpAndSettle();

    expect(find.text('Zatiaľ bez SALONOS dát'), findsOneWidget);
  });

  testWidgets('shows an API error state', (tester) async {
    final failure = Future<SalonosStats>.delayed(
      Duration.zero,
      () => throw const SalonosStatsException('Server unavailable.'),
    );
    await tester.pumpWidget(_app(failure));
    await tester.pumpAndSettle();

    expect(find.text('SALONOS dáta sa nepodarilo načítať'), findsOneWidget);
    expect(find.text('Server unavailable.'), findsOneWidget);
    expect(find.text('Skúsiť znova'), findsOneWidget);
  });
}
