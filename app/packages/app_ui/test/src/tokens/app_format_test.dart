import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppFormat', () {
    test('placeholder is an em dash', () {
      expect(AppFormat.placeholder, '—');
    });

    test('kcal groups and drops decimals', () {
      expect(AppFormat.kcal(1850.4, locale: 'en'), '1,850 kcal');
      expect(AppFormat.kcal(1850.4, locale: 'de'), '1.850 kcal');
    });

    test('grams keeps one decimal only under 10', () {
      expect(AppFormat.grams(12.4, locale: 'en'), '12 g');
      expect(AppFormat.grams(2.5, locale: 'en'), '2.5 g');
      expect(AppFormat.grams(3, locale: 'en'), '3 g');
      expect(AppFormat.grams(-12.4, locale: 'en'), '-12 g');
      expect(AppFormat.grams(2.5, locale: 'es'), '2,5 g');
    });

    test('nutrient keeps up to one decimal at any size', () {
      expect(AppFormat.nutrient(16.94, locale: 'en'), '16.9 g');
      expect(AppFormat.nutrient(120, unit: 'mg', locale: 'en'), '120 mg');
    });

    test('weight converts from kilograms', () {
      expect(
        AppFormat.weight(82.5, AppWeightUnit.kilograms, locale: 'en'),
        '82.5 kg',
      );
      expect(
        AppFormat.weight(82.5, AppWeightUnit.pounds, locale: 'en'),
        '181.9 lb',
      );
      expect(
        AppFormat.weight(
          0.25,
          AppWeightUnit.kilograms,
          maxFractionDigits: 2,
          locale: 'en',
        ),
        '0.25 kg',
      );
    });

    test('distance converts from metres', () {
      expect(
        AppFormat.distance(5230, AppDistanceUnit.kilometers, locale: 'en'),
        '5.2 km',
      );
      expect(
        AppFormat.distance(5150, AppDistanceUnit.miles, locale: 'en'),
        '3.2 mi',
      );
    });

    test('setCount rounds to one decimal', () {
      expect(AppFormat.setCount(12, locale: 'en'), '12');
      expect(AppFormat.setCount(2.46, locale: 'en'), '2.5');
      expect(AppFormat.setCount(2.5, locale: 'es'), '2,5');
    });

    test('repRange uses an en dash', () {
      expect(AppFormat.repRange(8, 12, locale: 'en'), '8–12');
    });

    test('duration drops the hour under an hour', () {
      expect(AppFormat.duration(Duration.zero), '0:00');
      expect(AppFormat.duration(const Duration(seconds: 270)), '4:30');
      expect(
        AppFormat.duration(const Duration(seconds: 3930, milliseconds: 900)),
        '1:05:30',
      );
    });

    test('percent follows the locale', () {
      expect(AppFormat.percent(0.454, locale: 'en'), '45%');
      expect(AppFormat.percent(0.45, locale: 'es'), contains('45'));
    });

    test('number defaults to no decimals', () {
      expect(AppFormat.number(1850.6, locale: 'en'), '1,851');
    });

    test('units carry their symbols', () {
      expect(AppWeightUnit.pounds.symbol, 'lb');
      expect(AppDistanceUnit.miles.symbol, 'mi');
    });
  });

  group('AppFormat dates', () {
    // 13:05 on Sunday 18 October 2026.
    final at = DateTime(2026, 10, 18, 13, 5);

    test('dateLocale is the app language with the device region', () {
      expect(
        AppFormat.dateLocale(const Locale('en'), const Locale('en', 'IE')),
        'en_IE',
      );
      expect(
        AppFormat.dateLocale(const Locale('es'), const Locale('fr', 'FR')),
        'es_FR',
      );
      expect(
        AppFormat.dateLocale(const Locale('en'), const Locale('en')),
        'en',
      );
      expect(
        AppFormat.dateLocale(const Locale('en'), const Locale.fromSubtags()),
        'en',
      );
    });

    test('date follows the region', () {
      expect(AppFormat.date(at, locale: 'en_US'), 'Oct 18, 2026');
      expect(AppFormat.date(at, locale: 'en_GB'), '18 Oct 2026');
      expect(AppFormat.date(at, locale: 'en_IE'), '18 Oct 2026');
      expect(AppFormat.date(at, locale: 'es_ES'), '18 oct 2026');
    });

    test('date takes a language tag', () {
      expect(AppFormat.date(at, locale: 'en-GB'), '18 Oct 2026');
    });

    test('an unknown region falls back to the language', () {
      expect(AppFormat.date(at, locale: 'en_FR'), 'Oct 18, 2026');
      expect(AppFormat.date(at, locale: 'es_FR'), '18 oct 2026');
    });

    test('an unknown language falls back to English', () {
      expect(AppFormat.date(at, locale: 'xx_YY'), 'Oct 18, 2026');
    });

    test('every style', () {
      String gb(AppDateStyle style) =>
          AppFormat.date(at, style: style, locale: 'en_GB');
      expect(gb(AppDateStyle.long), '18 October 2026');
      expect(gb(AppDateStyle.full), 'Sunday, 18 October 2026');
      expect(gb(AppDateStyle.weekdayMedium), 'Sun, 18 Oct 2026');
      expect(gb(AppDateStyle.dayMonth), '18 Oct');
      expect(gb(AppDateStyle.weekdayDayMonth), 'Sun 18 Oct');
      expect(gb(AppDateStyle.weekdayDayMonthLong), 'Sunday 18 October');
      expect(gb(AppDateStyle.monthYear), 'October 2026');
      expect(gb(AppDateStyle.month), 'Oct');
      expect(gb(AppDateStyle.weekday), 'Sunday');
      expect(gb(AppDateStyle.weekdayShort), 'Sun');
      expect(gb(AppDateStyle.weekdayInitial), 'S');
      expect(gb(AppDateStyle.day), '18');
      expect(
        AppFormat.date(at, style: AppDateStyle.long, locale: 'es_ES'),
        '18 de octubre de 2026',
      );
    });

    test('time follows the 24-hour setting', () {
      expect(
        AppFormat.time(at, use24HourFormat: true, locale: 'en_US'),
        '13:05',
      );
      expect(
        AppFormat.time(at, use24HourFormat: false, locale: 'en_US'),
        '1:05 PM',
      );
      expect(
        AppFormat.time(at, use24HourFormat: false, locale: 'en_GB'),
        '1:05 pm',
      );
      expect(
        AppFormat.time(at, use24HourFormat: true, locale: 'en_GB'),
        '13:05',
      );
      expect(
        AppFormat.time(at, use24HourFormat: true, locale: 'es_ES'),
        '13:05',
      );
      expect(
        AppFormat.time(at, use24HourFormat: false, locale: 'es_ES'),
        '1:05 p.\u202fm.',
      );
    });

    test('hour follows the 24-hour setting', () {
      expect(
        AppFormat.hour(7, use24HourFormat: false, locale: 'en_US'),
        '7 AM',
      );
      expect(AppFormat.hour(7, use24HourFormat: true, locale: 'en_GB'), '07');
      expect(
        AppFormat.hour(19, use24HourFormat: false, locale: 'en_IE'),
        '7 p.m.',
      );
    });

    test('dateTime joins as the language does', () {
      expect(
        AppFormat.dateTime(at, use24HourFormat: true, locale: 'en_GB'),
        '18 Oct 2026 at 13:05',
      );
      expect(
        AppFormat.dateTime(
          at,
          use24HourFormat: false,
          style: AppDateStyle.long,
          locale: 'en_US',
        ),
        'October 18, 2026 at 1:05 PM',
      );
      expect(
        AppFormat.dateTime(at, use24HourFormat: true, locale: 'es_ES'),
        '18 oct 2026, 13:05',
      );
    });

    testWidgets('context reads the device region and clock', (tester) async {
      tester.platformDispatcher.localeTestValue = const Locale('en', 'IE');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      late String locale;
      late bool use24;
      await tester.pumpWidget(
        Localizations(
          locale: const Locale('en'),
          delegates: const [DefaultWidgetsLocalizations.delegate],
          child: MediaQuery(
            data: const MediaQueryData(alwaysUse24HourFormat: true),
            child: Builder(
              builder: (context) {
                locale = context.dateLocale;
                use24 = context.use24HourFormat;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(locale, 'en_IE');
      expect(use24, isTrue);
    });
  });
}
