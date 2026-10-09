//
//  EnergyDensity.swift
//  Compound
//
//  The energy in a kilogram of body-weight change: the one figure that turns a weight trend into
//  kcal and a goal rate into a daily deficit. Every such conversion goes through here, so the app
//  never mixes figures (it once used 7,700 kcal/kg in one place and 3,500 kcal/lb in another).
//
//  With a body fat percentage, the change is split between fat and fat-free mass by Forbes' curve
//  as Hall formulated it: the leaner the person, the more of each kilogram is lean tissue, which
//  holds far less energy. Without one it falls back to the conventional 7,700 kcal/kg, which is the
//  Forbes figure for roughly 25–30 kg of fat mass.
//
//  Sources: Forbes 1987 (R27) and Hall 2008 (R24) for the partition and the two densities;
//  Wishnofsky 1958 (R23) for the 7,700 convention. See MethodInfo.energyDensity.
//

import Foundation

enum EnergyDensity {

    /// The conventional figure, used when fat mass is unknown.
    static let conventionalKcalPerKg: Double = 7700

    /// Energy density of fat tissue change (Hall 2008: 39.5 MJ/kg).
    static let fatKcalPerKg: Double = 9440

    /// Energy density of fat-free mass change (Hall 2008: 7.6 MJ/kg).
    static let leanKcalPerKg: Double = 1816

    /// Forbes' constant C in kg: the share of a change that is fat is FM / (FM + C).
    static let forbesConstantKg: Double = 10.4

    /// kcal per kg of weight change for someone with this much fat mass, or the conventional figure
    /// when fat mass is unknown or not plausible.
    static func kcalPerKg(fatMassKg: Double?) -> Double {
        guard let fatMassKg, fatMassKg.isFinite, fatMassKg > 0 else { return conventionalKcalPerKg }
        let fatShare = fatMassKg / (fatMassKg + forbesConstantKg)
        return fatShare * fatKcalPerKg + (1 - fatShare) * leanKcalPerKg
    }

    /// kcal per kg from body weight and body fat percentage (0–100), either of which may be missing.
    static func kcalPerKg(weightKg: Double?, bodyFatPercent: Double?) -> Double {
        guard let weightKg, let bodyFatPercent, weightKg.isFinite, bodyFatPercent.isFinite,
              bodyFatPercent > 0, bodyFatPercent < 100 else { return conventionalKcalPerKg }
        return kcalPerKg(fatMassKg: weightKg * bodyFatPercent / 100)
    }

    /// The daily energy difference that moves weight by `weeklyChangeKg` a week.
    static func dailyKcal(forWeeklyChangeKg weeklyChangeKg: Double, kcalPerKg: Double = conventionalKcalPerKg) -> Double {
        weeklyChangeKg * kcalPerKg / 7
    }
}
