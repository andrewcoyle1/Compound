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
}
