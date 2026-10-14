import 'package:intl/intl.dart';

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
/// Every function takes `locale` for tests; callers leave it out, which uses
/// `Intl.defaultLocale`.
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
}
