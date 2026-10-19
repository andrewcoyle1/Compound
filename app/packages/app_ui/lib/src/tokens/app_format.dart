import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// How much of a date [AppFormat.date] writes. Each is an `intl` skeleton, so
/// the order, punctuation and month names follow the locale: `18 Oct 2026` in
/// en_GB, `Oct 18, 2026` in en_US, `18 oct 2026` in es_ES.
enum AppDateStyle {
  /// `18 Oct 2026` (Swift `date: .abbreviated`).
  medium('yMMMd'),

  /// `18 October 2026` (Swift `date: .long`).
  long('yMMMMd'),

  /// `Sunday, 18 October 2026` (Swift `date: .complete`).
  full('yMMMMEEEEd'),

  /// `Sun, 18 Oct 2026`.
  weekdayMedium('yMMMEd'),

  /// `18 Oct`.
  dayMonth('MMMd'),

  /// `Sun, 18 Oct`.
  weekdayDayMonth('MMMEd'),

  /// `Sunday, 18 October`.
  weekdayDayMonthLong('MMMMEEEEd'),

  /// `October 2026`.
  monthYear('yMMMM'),

  /// `Oct`.
  month('MMM'),

  /// `Sunday`.
  weekday('EEEE'),

  /// `Sun`.
  weekdayShort('E'),

  /// `S`, for a column of days.
  weekdayInitial('EEEEE'),

  /// `18`.
  day('d');

  new(this.skeleton);

  /// The `intl` skeleton.
  final String skeleton;
}

/// A unit a body weight or load is shown in.
enum AppWeightUnit {
  /// Kilograms, `kg`.
  kilograms('kg'),

  /// Pounds, `lb`.
  pounds('lb');

  new(this.symbol);

  /// The unit's symbol, the same in every language.
  final String symbol;
}

/// A unit a distance is shown in.
enum AppDistanceUnit {
  /// Kilometres, `km`.
  kilometers('km'),

  /// Miles, `mi`.
  miles('mi');

  new(this.symbol);

  /// The unit's symbol, the same in every language.
  final String symbol;
}

/// Display strings for numbers with units, locale-aware through `intl`.
///
/// Only numbers and unit symbols (`kcal`, `g`, `kg`, `lb`, `km`, `mi`), which
/// read the same in every language the app ships. Words and plurals ("8 reps",
/// "1 set") belong to the app's ARB strings: pass them the number formatted
/// here, such as [setCount].
///
/// - A missing value is [placeholder], never "--" or "0":
///   `value == null ? AppFormat.placeholder : AppFormat.kcal(value)`.
/// - Weight and distance take the stored metric value and convert it.
///
/// Every number function takes `locale` for tests; callers leave it out,
/// which uses `Intl.defaultLocale`.
///
/// Dates and times are written in the device's region, not only the app's
/// language: callers pass `locale: context.dateLocale` (see [dateLocale]),
/// and times take `use24HourFormat: context.use24HourFormat`. Never call
/// `DateFormat` in feature code.
abstract final class AppFormat {
  /// Shown in place of a missing value.
  static const placeholder = '—';

  /// Pounds in a kilogram, as the Swift app's `UnitConversion` has it.
  static const poundsPerKilogram = 2.20462;

  /// Miles in a metre, as the Swift app's `UnitConversion` has it.
  static const milesPerMeter = 0.000621371;

  /// `1,850 kcal`, no decimals.
  static String kcal(num value, {String? locale}) =>
      '${number(value, locale: locale)} kcal';

  /// `12 g`. No decimals from 10 g up; up to one below, so `2.5 g` but `3 g`.
  static String grams(num value, {String? locale}) {
    final digits = value.abs() >= 10 ? 0 : 1;
    return '${number(value, maxFractionDigits: digits, locale: locale)} g';
  }

  /// `16.9 g`, `120 mg`: up to one decimal at any size, for nutrition labels
  /// and nutrient tables. Elsewhere use [grams].
  static String nutrient(num value, {String unit = 'g', String? locale}) =>
      '${number(value, maxFractionDigits: 1, locale: locale)} $unit';

  /// `82.5 kg` / `181.9 lb`, up to [maxFractionDigits] decimals, from a value
  /// stored in kilograms. A weekly rate passes 2, because at one decimal
  /// 0.25 kg reads `0.2 kg`.
  static String weight(
    num kilograms,
    AppWeightUnit unit, {
    int maxFractionDigits = 1,
    String? locale,
  }) {
    final value = switch (unit) {
      AppWeightUnit.kilograms => kilograms,
      AppWeightUnit.pounds => kilograms * poundsPerKilogram,
    };
    final shown = number(
      value,
      maxFractionDigits: maxFractionDigits,
      locale: locale,
    );
    return '$shown ${unit.symbol}';
  }

  /// `5.2 km` / `3.2 mi`, up to one decimal, from a value stored in metres.
  static String distance(num meters, AppDistanceUnit unit, {String? locale}) {
    final value = switch (unit) {
      AppDistanceUnit.kilometers => meters / 1000,
      AppDistanceUnit.miles => meters * milesPerMeter,
    };
    return '${number(value, maxFractionDigits: 1, locale: locale)} '
        '${unit.symbol}';
  }

  /// A set count for the ARB plural: `12`, `2.5`. Rounded to one decimal,
  /// since a muscle an exercise only assists earns half a set. A fractional
  /// count is always plural.
  static String setCount(num count, {String? locale}) =>
      number((count * 10).round() / 10, maxFractionDigits: 1, locale: locale);

  /// `8–12`, with an en dash.
  static String repRange(int lower, int upper, {String? locale}) =>
      '${number(lower, locale: locale)}–${number(upper, locale: locale)}';

  /// `4:30` under an hour, `1:05:30` from an hour up. Fractions of a second
  /// are dropped.
  static String duration(Duration duration) {
    final seconds = duration.inSeconds;
    String two(int n) => n.toString().padLeft(2, '0');
    final minutesAndSeconds = '${two(seconds ~/ 60 % 60)}:${two(seconds % 60)}';
    if (seconds >= 3600) return '${seconds ~/ 3600}:$minutesAndSeconds';
    return '${seconds ~/ 60}:${two(seconds % 60)}';
  }

  /// `45%` from a fraction (`0.45`), no decimals, with the locale's spacing
  /// (`45 %` in Spanish).
  static String percent(num fraction, {String? locale}) =>
      NumberFormat.percentPattern(locale).format(fraction);

  /// [value] with grouping and up to [maxFractionDigits] decimals, trailing
  /// zeros dropped: `1,850`, `82.5`.
  static String number(num value, {int maxFractionDigits = 0, String? locale}) {
    final format = NumberFormat.decimalPattern(locale)
      ..minimumFractionDigits = 0
      ..maximumFractionDigits = maxFractionDigits;
    return format.format(value);
  }

  /// The locale dates are written in: the app's [language] with the
  /// [device]'s region, as iOS composes it. English on an Irish phone is
  /// `en_IE` (`18 Oct 2026`) though the app has only `en` strings; Spanish
  /// in Spain is `es_ES`. With no region it is the language alone.
  static String dateLocale(Locale language, Locale device) {
    final region = device.countryCode;
    if (region == null || region.isEmpty) return language.languageCode;
    return '${language.languageCode}_$region';
  }

  /// [date] in [style], `18 Oct 2026` by default.
  static String date(
    DateTime date, {
    AppDateStyle style = AppDateStyle.medium,
    String? locale,
  }) => _dateFormat(style.skeleton, locale).format(date);

  /// A time of day: `13:00` on the 24-hour clock, `1:00 pm` (en_GB) or
  /// `1:00 PM` (en_US) on the 12-hour one. [use24HourFormat] is the device's
  /// setting, which already reflects the region's default, so it decides.
  static String time(
    DateTime time, {
    required bool use24HourFormat,
    String? locale,
  }) => _dateFormat(use24HourFormat ? 'Hm' : 'h:mm a', locale).format(time);

  /// An hour of the day on its own: `07` or `7 AM` (Swift
  /// `FoodLogSettingsPresenter.hourLabel`).
  static String hour(
    int hour, {
    required bool use24HourFormat,
    String? locale,
  }) => _dateFormat(
    use24HourFormat ? 'H' : 'h a',
    locale,
  ).format(DateTime(2000, 1, 1, hour));

  /// [date] then its [time]: `18 Oct 2026 at 13:00`, `18 oct 2026, 13:00`
  /// (Swift `formatted(date:time: .shortened)`).
  static String dateTime(
    DateTime dateTime, {
    required bool use24HourFormat,
    AppDateStyle style = AppDateStyle.medium,
    String? locale,
  }) {
    final day = date(dateTime, style: style, locale: locale);
    final at = time(dateTime, use24HourFormat: use24HourFormat, locale: locale);
    // CLDR joins with "at" in English and a comma elsewhere.
    final language = Intl.shortLocale(_verified(locale));
    return language == 'en' ? '$day at $at' : '$day, $at';
  }

  static bool _dateSymbolsLoaded = false;

  static DateFormat _dateFormat(String pattern, String? locale) {
    if (!_dateSymbolsLoaded) {
      // Synchronous despite the Future, and a no-op once flutter_localizations
      // has loaded its own set (which covers the same en and es regions).
      // ignore: discarded_futures
      initializeDateFormatting();
      _dateSymbolsLoaded = true;
    }
    return DateFormat(pattern, _verified(locale));
  }

  /// [locale], or its language when `intl` has no data for the region
  /// (`en_FR` is `en`), or English when it knows neither.
  static String _verified(String? locale) => Intl.verifiedLocale(
    locale,
    DateFormat.localeExists,
    onFailure: (_) => 'en',
  )!;
}

/// The device settings [AppFormat]'s dates and times need.
extension AppFormatContext on BuildContext {
  /// [AppFormat.dateLocale] for the app's language and this device's region.
  String get dateLocale => AppFormat.dateLocale(
    Localizations.localeOf(this),
    View.of(this).platformDispatcher.locale,
  );

  /// Whether the device writes times on the 24-hour clock.
  bool get use24HourFormat => MediaQuery.alwaysUse24HourFormatOf(this);
}
