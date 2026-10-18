import 'package:compound/l10n/l10n.dart';
import 'package:compound/widgets/relative_time.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Expected values are what Swift's `.relative(presentation: .named)` printed
/// for the same gaps on 18 Oct 2026 (a Sunday), on a Monday-first calendar
/// unless noted.
void main() {
  // Local times, so the calendar arithmetic holds in any time zone. No
  // daylight-saving change falls in the year before this date in the zones
  // CI runs in.
  final now = DateTime(2026, 10, 18, 11, 3);

  DateTime ago({
    int years = 0,
    int months = 0,
    int days = 0,
    int hours = 0,
    int minutes = 0,
    int seconds = 0,
    int milliseconds = 0,
  }) => DateTime(
    now.year - years,
    now.month - months,
    now.day - days,
    now.hour - hours,
    now.minute - minutes,
    now.second - seconds,
    -milliseconds,
  );

  String of(DateTime date, {int firstWeekday = DateTime.monday}) {
    final (:unit, :count) = relativeTimeOf(
      date,
      now: now,
      firstWeekday: firstWeekday,
    );
    return '$count ${unit.name}';
  }

  group('relativeTimeOf', () {
    test('rounds the gap to whole seconds', () {
      expect(of(ago(milliseconds: 400)), '0 second');
      expect(of(ago(milliseconds: 600)), '1 second');
      expect(of(ago(seconds: 59, milliseconds: 600)), '1 minute');
    });

    test('a date in the future is now', () {
      expect(of(now.add(const Duration(seconds: 3))), '0 second');
    });

    test('under a day, rounds half up on the next unit', () {
      expect(of(ago(seconds: 45)), '45 second');
      expect(of(ago(minutes: 1, seconds: 29)), '1 minute');
      expect(of(ago(minutes: 1, seconds: 30)), '2 minute');
      expect(of(ago(minutes: 59, seconds: 29)), '59 minute');
      expect(of(ago(minutes: 59, seconds: 30)), '1 hour');
      expect(of(ago(hours: 1, minutes: 29)), '1 hour');
      expect(of(ago(hours: 1, minutes: 30)), '2 hour');
      expect(of(ago(hours: 23, minutes: 29)), '23 hour');
      expect(of(ago(hours: 23, minutes: 30)), '1 day');
    });

    test('days count calendar days', () {
      expect(of(ago(days: 1, hours: 11)), '1 day');
      expect(of(ago(days: 1, hours: 12)), '2 day');
      expect(of(ago(days: 6, hours: 11)), '6 day');
      expect(of(ago(days: 6, hours: 12)), '1 week');
    });

    test('weeks count from the start of the week', () {
      expect(of(ago(days: 13)), '1 week');
      expect(of(ago(days: 13, hours: 23)), '2 week');
      expect(of(ago(days: 27)), '3 week');
      expect(of(ago(days: 27, hours: 12)), '4 week');
      expect(of(ago(days: 8), firstWeekday: DateTime.sunday), '2 week');
      expect(of(ago(days: 7), firstWeekday: DateTime.sunday), '1 week');
    });

    test('months and years count calendar months and years', () {
      expect(of(ago(days: 35)), '1 month');
      expect(of(ago(months: 1, days: 17)), '1 month');
      expect(of(ago(months: 1, days: 18)), '2 month');
      expect(of(ago(months: 11, days: 21)), '1 year');
      expect(of(ago(years: 1, months: 6)), '1 year');
      expect(of(ago(years: 2)), '2 year');
    });

    test('a month too short for the day ends on its last day', () {
      // Stepping back a month from 31 March lands on 28 February, not on
      // 3 March.
      final march = DateTime(2026, 3, 31, 12);
      expect(
        relativeTimeOf(DateTime(2026, 2, 28, 13), now: march).unit,
        RelativeUnit.month,
      );
    });
  });

  group('relativeTimeText', () {
    Future<void> check(
      WidgetTester tester,
      Locale locale,
      Map<DateTime, String> expected,
    ) async {
      late AppLocalizations l10n;
      await tester.pumpWidget(
        Localizations(
          locale: locale,
          delegates: AppLocalizations.localizationsDelegates,
          child: Builder(
            builder: (context) {
              l10n = context.l10n;
              return const SizedBox();
            },
          ),
        ),
      );
      for (final MapEntry(:key, :value) in expected.entries) {
        expect(relativeTimeText(l10n, key, now: now), value);
      }
    }

    testWidgets('in English', (tester) async {
      await check(tester, const Locale('en'), {
        now: 'now',
        ago(seconds: 1): '1 second ago',
        ago(seconds: 30): '30 seconds ago',
        ago(minutes: 1): '1 minute ago',
        ago(minutes: 5): '5 minutes ago',
        ago(hours: 1): '1 hour ago',
        ago(hours: 2): '2 hours ago',
        ago(days: 1): 'yesterday',
        ago(days: 2): '2 days ago',
        ago(days: 8): 'last week',
        ago(days: 20): '2 weeks ago',
        ago(months: 1): 'last month',
        ago(months: 3): '3 months ago',
        ago(years: 1): 'last year',
        ago(years: 3): '3 years ago',
      });
    });

    testWidgets('in Spanish', (tester) async {
      await check(tester, const Locale('es'), {
        now: 'ahora',
        ago(seconds: 1): 'hace 1 segundo',
        ago(seconds: 30): 'hace 30 segundos',
        ago(minutes: 1): 'hace 1 minuto',
        ago(minutes: 5): 'hace 5 minutos',
        ago(hours: 1): 'hace 1 hora',
        ago(hours: 2): 'hace 2 horas',
        ago(days: 1): 'ayer',
        ago(days: 2): 'anteayer',
        ago(days: 3): 'hace 3 días',
        ago(days: 8): 'la semana pasada',
        ago(days: 20): 'hace 2 semanas',
        ago(months: 1): 'el mes pasado',
        ago(months: 3): 'hace 3 meses',
        ago(years: 1): 'el año pasado',
        ago(years: 3): 'hace 3 años',
      });
    });
  });

  group('RelativeTimeBuilder', () {
    testWidgets('builds again as the time moves on', (tester) async {
      var clock = now;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RelativeTimeBuilder(
            date: now.subtract(const Duration(seconds: 58)),
            now: () => clock,
            builder: (context, text) => Text(text),
          ),
        ),
      );
      expect(find.text('58 seconds ago'), findsOneWidget);
      clock = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('59 seconds ago'), findsOneWidget);
      for (final (gap, wait, text) in [
        (
          const Duration(minutes: 2),
          const Duration(seconds: 1),
          '2 minutes ago',
        ),
        (const Duration(hours: 2), const Duration(seconds: 30), '2 hours ago'),
        (const Duration(days: 3), const Duration(minutes: 5), '3 days ago'),
        (const Duration(days: 4), const Duration(hours: 1), '4 days ago'),
      ]) {
        clock = now.subtract(const Duration(seconds: 58)).add(gap);
        await tester.pump(wait);
        expect(find.text(text), findsOneWidget);
      }
    });
  });
}
