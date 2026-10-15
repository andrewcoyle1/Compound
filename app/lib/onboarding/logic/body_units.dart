/// The unit arithmetic of the account-setup and goal screens
/// (`UnitConversion.swift`, `HeightPresenter`, `WeightPresenter`).
library;

/// Pounds in a kilogram, as `UnitConversion` converts.
const poundsPerKilogram = 2.20462;

/// `UnitConversion.kgToLbs`.
double kgToLbs(double kilograms) => kilograms * poundsPerKilogram;

/// `UnitConversion.lbsToKg`.
double lbsToKg(double pounds) => pounds / poundsPerKilogram;

/// The height wheel's range, in centimetres.
const ({int min, int max}) centimetresRange = (min: 100, max: 250);

/// The weight wheels' ranges (`WeightPresenter.kilogramsRange`,
/// `poundsRange`).
const ({int min, int max}) kilogramsRange = (min: 30, max: 500);

/// See [kilogramsRange].
const ({int min, int max}) poundsRange = (min: 66, max: 1100);

/// Feet and inches for [centimetres], split from one rounded total of
/// inches so they cannot disagree (`updateImperialFromCentimeters`).
({int feet, int inches}) imperialHeight(int centimetres) {
  final totalInches = (centimetres / 2.54).round();
  return (feet: totalInches ~/ 12, inches: totalInches % 12);
}

/// Whole centimetres for [feet] and [inches], rounded rather than
/// truncated (`updateCentimetersFromImperial`).
int centimetresFromImperial(int feet, int inches) =>
    ((feet * 12 + inches) * 2.54).round();

/// The pounds wheel's value for [kilograms] (`updatePoundsFromKilograms`).
int poundsFromKilograms(int kilograms) => kgToLbs(kilograms.toDouble()).round();

/// The kilograms wheel's value for [pounds] (`updateKilogramsFromPounds`).
int kilogramsFromPounds(int pounds) => lbsToKg(pounds.toDouble()).round();

/// The weight saved from the pounds wheel. Swift's `WeightPresenter.weight`
/// uses 0.453592 here, not [poundsPerKilogram]; kept, so both apps store
/// the same figure.
double kilogramsFromPoundsWheel(int pounds) => pounds * 0.453592;

/// Whole years from [dateOfBirth] to [now], in local time.
int wholeYears(DateTime dateOfBirth, DateTime now) {
  final birth = dateOfBirth.toLocal();
  final at = now.toLocal();
  var years = at.year - birth.year;
  if (at.month < birth.month ||
      (at.month == birth.month && at.day < birth.day)) {
    years--;
  }
  return years;
}
