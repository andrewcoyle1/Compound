import 'package:compound/log_weight/logic/decimal_wheel_value.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors `DecimalWheelValueTests.swift`.
void main() {
  group(DecimalWheelValue, () {
    test('splits a value with no rounding needed', () {
      expect(DecimalWheelValue.split(82.4), (whole: 82, tenths: 4));
    });

    test('a whole-number entry splits to tenths of 0', () {
      expect(DecimalWheelValue.split(82), (whole: 82, tenths: 0));
    });

    test('rounds to the nearest tenth rather than truncating', () {
      expect(DecimalWheelValue.split(82.449), (whole: 82, tenths: 4));
      expect(DecimalWheelValue.split(82.46), (whole: 82, tenths: 5));
    });

    test('a tenths carry rolls into the whole number', () {
      expect(DecimalWheelValue.split(9.96), (whole: 10, tenths: 0));
    });

    test('combine is the inverse of split', () {
      expect(DecimalWheelValue.combine(whole: 82, tenths: 4), 82.4);
      expect(DecimalWheelValue.combine(whole: 82, tenths: 0), 82.0);
    });

    test('round trips through split and combine', () {
      for (final value in [30.0, 82.4, 99.9, 100.0, 154.7, 200.0]) {
        final (:whole, :tenths) = DecimalWheelValue.split(value);
        expect(DecimalWheelValue.combine(whole: whole, tenths: tenths), value);
      }
    });

    test('the tenths wheel runs 0 to 9', () {
      expect(DecimalWheelValue.tenths, [for (var i = 0; i < 10; i++) i]);
    });
  });

  test('the wheels span what Swift offers', () {
    expect(WeightWheelRange.kilograms, (min: 30, max: 200));
    expect(WeightWheelRange.pounds, (min: 66, max: 440));
  });
}
