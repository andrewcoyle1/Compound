/// kcal per kilogram of weight change (`EnergyDensity.swift`).
library;

/// The energy-density constants.
abstract final class EnergyDensity {
  /// Used when body fat is unknown.
  static const conventionalKcalPerKg = 7700.0;

  /// Energy density of fat mass (Hall 2008).
  static const fatKcalPerKg = 9440.0;

  /// Energy density of fat-free mass (Hall 2008).
  static const leanKcalPerKg = 1816.0;

  /// Forbes' constant (Forbes 1987; Hall 2007).
  static const forbesConstantKg = 10.4;
}

/// Forbes' partition of a change into fat and fat-free mass, times their energy
/// densities; [EnergyDensity.conventionalKcalPerKg] without a usable weight and
/// body fat percentage.
double energyDensityKcalPerKg(double? weightKg, double? bodyFatPercent) {
  if (weightKg == null ||
      bodyFatPercent == null ||
      !weightKg.isFinite ||
      !(bodyFatPercent > 0 && bodyFatPercent < 100)) {
    return EnergyDensity.conventionalKcalPerKg;
  }
  final fatMassKg = weightKg * bodyFatPercent / 100;
  if (!(fatMassKg > 0)) return EnergyDensity.conventionalKcalPerKg;
  final fatShare = fatMassKg / (fatMassKg + EnergyDensity.forbesConstantKg);
  return fatShare * EnergyDensity.fatKcalPerKg +
      (1 - fatShare) * EnergyDensity.leanKcalPerKg;
}
