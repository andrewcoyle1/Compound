/// A value shown as two wheel columns, whole units and tenths, so 82.4 kg can
/// be entered without a decimal keypad (Swift `DecimalWheelValue`).
abstract final class DecimalWheelValue {
  /// The tenths wheel's values.
  static const tenths = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];

  /// Rounds [value] to the nearest tenth and splits it into a whole part and
  /// a 0–9 tenths digit, carrying 9.96 to (10, 0) rather than a tenths digit
  /// of 10.
  static ({int whole, int tenths}) split(double value) {
    final scaledTenths = (value * 10).round();
    return (whole: scaledTenths ~/ 10, tenths: scaledTenths % 10);
  }

  /// The inverse of [split].
  static double combine({required int whole, required int tenths}) =>
      whole + tenths / 10;
}

/// The whole-number wheel's span in each unit (Swift
/// `WeightPickerInput.kilogramRange`, `.poundRange`).
abstract final class WeightWheelRange {
  /// 30–200 kg.
  static const ({int min, int max}) kilograms = (min: 30, max: 200);

  /// 66–440 lb.
  static const ({int min, int max}) pounds = (min: 66, max: 440);
}
