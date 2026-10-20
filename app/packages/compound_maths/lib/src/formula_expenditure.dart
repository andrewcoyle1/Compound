/// Formula expenditure, the prior the adaptive engine starts from
/// (`FormulaExpenditure.swift`, `NutritionManager.estimateTDEE`).
library;

/// Sex as stored (`Gender` in `UserModel.swift`), with Mifflin-St Jeor's sex
/// term: the midpoint when not said.
enum Gender(final String rawValue, final double mifflinStJeorCoefficient) {
  male('male', 5),
  female('female', -161),
  preferNotToSay('prefer_not_to_say', -78);

  /// The case stored as [raw], or `null`.
  static Gender? tryParse(String? raw) =>
      values.where((g) => g.rawValue == raw).firstOrNull;
}

/// The daily activity answer (`ActivityLevel`) as stored, with the physical
/// activity level (PAL) the resting rate is multiplied by.
///
/// One PAL per answer inside the FAO/WHO/UNU 2004 bands, with no term for
/// training frequency.
enum ActivityLevel(final String rawValue, final double multiplier) {
  sedentary('sedentary', 1.4),
  light('light', 1.55),
  moderate('moderate', 1.7),
  active('active', 1.85),
  veryActive('very_active', 2);

  /// The case stored as [raw], or `null`.
  static ActivityLevel? tryParse(String? raw) =>
      values.where((a) => a.rawValue == raw).firstOrNull;
}

/// The resting-rate equation (`BMREquation`).
enum BmrEquation(final String rawValue) {
  mifflinStJeor('mifflinStJeor'),
  harrisBenedict('harrisBenedict'),

  /// Cunningham 1980; stored as "katchMcArdle", the equation it replaced.
  cunningham('katchMcArdle');

  /// The case stored as [raw], or `null`.
  static BmrEquation? tryParse(String? raw) =>
      values.where((e) => e.rawValue == raw).firstOrNull;
}

/// How the settings choose an equation (`ExpenditureEstimationMethod`).
enum ExpenditureEstimationMethod { standard, bodyFatAware }

/// The equation an estimate actually runs: Cunningham when body-fat aware and a
/// usable body fat percentage is known, else the one chosen
/// (`NutritionStrategySettings.resolvedBMREquation`).
BmrEquation resolvedBmrEquation({
  required BmrEquation equation,
  required ExpenditureEstimationMethod method,
  double? bodyFatPercentage,
}) {
  if (method != ExpenditureEstimationMethod.bodyFatAware ||
      bodyFatPercentage == null ||
      !(bodyFatPercentage > 0 && bodyFatPercentage < 100)) {
    return equation;
  }
  return BmrEquation.cunningham;
}

/// No estimate below this: Compound's own safeguard.
const minimumTotalKcal = 1000.0;

double _clamped(double? value, double low, double high, double fallback) {
  final v = value ?? fallback;
  return v.isFinite ? v.clamp(low, high) : fallback;
}

/// Resting rate × PAL, never below [minimumTotalKcal]
/// (`NutritionManager.estimateTDEE`).
///
/// A missing weight or height reads as 70 kg or 175 cm (clamped to 30–500 kg
/// and 120–260 cm), a missing age as 30, a missing sex as the midpoint and a
/// missing activity as moderate. [ageYears] is the caller's: the app counts
/// whole years from the date of birth, never under 14. Cunningham without a
/// usable [bodyFatPercentage] falls back to Mifflin-St Jeor.
double estimateTdee({
  Gender? gender,
  double? weightKg,
  double? heightCm,
  int? ageYears,
  ActivityLevel? activity,
  BmrEquation equation = BmrEquation.mifflinStJeor,
  double? bodyFatPercentage,
}) {
  final sex = gender ?? Gender.preferNotToSay;
  final weight = _clamped(weightKg, 30, 500, 70);
  final height = _clamped(heightCm, 120, 260, 175);
  final age = ageYears ?? 30;
  var resting =
      10 * weight + 6.25 * height - 5 * age + sex.mifflinStJeorCoefficient;
  switch (equation) {
    case BmrEquation.mifflinStJeor:
      break;
    case BmrEquation.harrisBenedict:
      final male = 88.362 + 13.397 * weight + 4.799 * height - 5.677 * age;
      final female = 447.593 + 9.247 * weight + 3.098 * height - 4.330 * age;
      resting = switch (sex) {
        Gender.male => male,
        Gender.female => female,
        Gender.preferNotToSay => (male + female) / 2,
      };
    case BmrEquation.cunningham:
      if (bodyFatPercentage != null &&
          bodyFatPercentage > 0 &&
          bodyFatPercentage < 100) {
        resting = 500 + 22 * (weight * (1 - bodyFatPercentage / 100));
      }
  }
  final total = resting * (activity ?? ActivityLevel.moderate).multiplier;
  return total > minimumTotalKcal ? total : minimumTotalKcal;
}
