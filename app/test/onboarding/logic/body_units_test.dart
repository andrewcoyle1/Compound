import 'package:compound/onboarding/logic/body_units.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors `OnboardingHeightConversionTests`.
void main() {
  test('six feet is 183 cm, not the 182 truncating gave', () {
    expect(centimetresFromImperial(6, 0), 183);
  });

  test('175 cm is 5 ft 9 in, not 5 ft 8 in', () {
    expect(imperialHeight(175), (feet: 5, inches: 9));
  });

  test('rounding up to twelve inches carries into the next foot', () {
    expect(imperialHeight(182), (feet: 6, inches: 0));
  });

  test('feet survive a trip through centimetres and back', () {
    expect(imperialHeight(centimetresFromImperial(5, 11)), (
      feet: 5,
      inches: 11,
    ));
  });

  test('weight wheels round between units', () {
    expect(poundsFromKilograms(70), 154);
    expect(kilogramsFromPounds(154), 70);
    expect(kilogramsFromPoundsWheel(154), closeTo(69.853168, 1e-9));
    expect(lbsToKg(kgToLbs(80)), closeTo(80, 1e-9));
  });

  test('whole years count the birthday', () {
    final now = DateTime(2026, 10, 15);
    expect(wholeYears(DateTime(1990, 10, 15), now), 36);
    expect(wholeYears(DateTime(1990, 10, 16), now), 35);
    expect(wholeYears(DateTime(1990, 11), now), 35);
  });
}
