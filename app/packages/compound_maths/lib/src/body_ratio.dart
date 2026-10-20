/// Waist-to-height and waist-to-hip, and where a ratio falls on its
/// screening bands (`BodyRatioMetric.swift`: `BodyRatioKind`,
/// `BodyRatioBand`, `BodyRatioPresenter.entries`). Screening, not
/// diagnosis.
library;

import 'package:compound_maths/src/formula_expenditure.dart' show Gender;

/// The two ratios the Body Metrics screen derives.
enum BodyRatioKind {
  /// Waist over the profile's height.
  waistToHeight,

  /// Waist over hips, from the same entry.
  waistToHip,
}

/// Where a ratio falls. Waist to height uses NICE NG246 (2025): under 0.50,
/// 0.50–0.59 increased risk, 0.60 and over high risk. Waist to hip uses the
/// WHO 2008 consultation (published 2011): 0.90 for men and 0.85 for women
/// mark a substantially increased risk.
enum BodyRatioBand {
  /// Waist to height under 0.50.
  underHalfHeight,

  /// Waist to height 0.50–0.59.
  increasedRisk,

  /// Waist to height 0.60 or more.
  highRisk,

  /// Waist to hip under the WHO cut-off.
  belowCutOff,

  /// Waist to hip at or over the WHO cut-off.
  substantiallyIncreasedRisk;

  /// Whether the band is a reason for concern.
  bool get isConcern => switch (this) {
    underHalfHeight || belowCutOff => false,
    increasedRisk || highRisk || substantiallyIncreasedRisk => true,
  };
}

/// Waist to height from which the risk is increased (NICE).
const increasedWaistToHeight = 0.50;

/// Waist to height from which the risk is high (NICE).
const highWaistToHeight = 0.60;

/// The WHO waist-to-hip cut-off for [sex]; none without a sex to apply.
double? waistToHipCutOff(Gender? sex) => switch (sex) {
  Gender.male => 0.90,
  Gender.female => 0.85,
  Gender.preferNotToSay || null => null,
};

/// [ratio]'s band for [kind]; none for waist to hip without a sex.
BodyRatioBand? bodyRatioBand(BodyRatioKind kind, double ratio, Gender? sex) {
  switch (kind) {
    case BodyRatioKind.waistToHeight:
      if (ratio >= highWaistToHeight) return BodyRatioBand.highRisk;
      if (ratio >= increasedWaistToHeight) return BodyRatioBand.increasedRisk;
      return BodyRatioBand.underHalfHeight;
    case BodyRatioKind.waistToHip:
      final cutOff = waistToHipCutOff(sex);
      if (cutOff == null) return null;
      return ratio >= cutOff
          ? BodyRatioBand.substantiallyIncreasedRisk
          : BodyRatioBand.belowCutOff;
  }
}

/// One entry's ratio, every length in centimetres, so no conversion: the
/// waist over the height, or over the same entry's hips. Null without a
/// positive waist, or a positive denominator.
double? bodyRatio(
  BodyRatioKind kind, {
  required double? waistCm,
  double? hipCm,
  double? heightCm,
}) {
  if (waistCm == null || !(waistCm > 0)) return null;
  final over = switch (kind) {
    BodyRatioKind.waistToHeight => heightCm,
    BodyRatioKind.waistToHip => hipCm,
  };
  if (over == null || !(over > 0)) return null;
  return waistCm / over;
}
