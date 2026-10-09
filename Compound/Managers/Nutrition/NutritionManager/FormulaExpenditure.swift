//
//  FormulaExpenditure.swift
//  Compound
//
//  The formula estimate of daily expenditure: a resting rate from an equation, multiplied by a
//  physical activity level (PAL). It is the prior the adaptive engine starts from, and the figure
//  onboarding shows. `NutritionManager.estimateTDEE` and the onboarding Expenditure step both call
//  this, so the two can no longer disagree (the onboarding step used to carry its own copy).
//
//  - Resting rate: Mifflin-St Jeor by default (Mifflin 1990, R1), Harris-Benedict as revised by
//    Roza and Shizgal (R2), or Cunningham 1980 (500 + 22 · fat-free mass, R8) when a body fat
//    percentage is known. Cunningham replaced Katch-McArdle, which no validation in athletes
//    supports (O'Neill 2023, R6; Tinsley 2019, R7).
//  - PAL: one value per activity answer, each inside the FAO/WHO/UNU 2004 lifestyle bands (R10),
//    with no extra term for training frequency. Those bands already include habitual exercise,
//    and total expenditure plateaus rather than adding up at high activity (Pontzer 2016, R11).
//  - Digesting food: 10% of the total (Westerterp 2004, R20). The rest above resting is activity.
//
//  `functions/coach-maths.js` (`estimateTDEE`) mirrors this line for line. See
//  `MethodInfo.formulaExpenditure` and `MethodInfo.restingMetabolicRate`.
//

import Foundation

enum FormulaExpenditure {

    /// The body inputs every resting equation draws on. Callers clamp their own figures first.
    struct Body: Sendable {
        let gender: Gender
        let weightKg: Double
        let heightCm: Double
        let ageYears: Double
        let bodyFatPercentage: Double?
    }

    /// One estimate and its three parts. The parts always add up to `totalKcal`.
    struct Estimate: Sendable, Equatable {
        let restingKcal: Double
        let activityMultiplier: Double
        let totalKcal: Double

        /// The energy spent digesting food: a fixed share of the total.
        var thermicEffectKcal: Double { totalKcal * FormulaExpenditure.thermicEffectShare }

        /// Everything above resting and digestion: daily movement and exercise together.
        var activityKcal: Double { max(totalKcal - restingKcal - thermicEffectKcal, 0) }
    }

    /// No estimate below this, so the smallest profile the pickers allow still yields a number a
    /// plan can be built from. Compound's own safeguard, not a physiological figure.
    static let minimumTotalKcal: Double = 1000

    /// Diet-induced thermogenesis on a mixed diet, as a share of daily expenditure (Westerterp
    /// 2004: about 10%).
    static let thermicEffectShare: Double = 0.10

    /// The PAL for each activity answer. Sedentary starts at 1.4, the bottom of FAO/WHO/UNU's
    /// "sedentary or light" band (1.40–1.69), not the 1.2 of bed rest; moderate sits in it, active
    /// in "active" (1.70–1.99) and very active at the start of "vigorous" (2.00–2.40). The exact
    /// values inside each band are Compound's choice.
    static func activityMultiplier(for level: ActivityLevel) -> Double {
        switch level {
        case .sedentary: return 1.4
        case .light: return 1.55
        case .moderate: return 1.7
        case .active: return 1.85
        case .veryActive: return 2.0
        }
    }

    /// Resting metabolic rate in kcal/day.
    ///
    /// Cunningham works from fat-free mass, so without a usable body fat percentage it has nothing
    /// to work from and falls back to Mifflin-St Jeor rather than inventing a figure.
    static func restingKcal(equation: BMREquation, body: Body) -> Double {
        switch equation {
        case .mifflinStJeor:
            return mifflinStJeor(body: body)
        case .harrisBenedict:
            let male = 88.362 + (13.397 * body.weightKg) + (4.799 * body.heightCm) - (5.677 * body.ageYears)
            let female = 447.593 + (9.247 * body.weightKg) + (3.098 * body.heightCm) - (4.330 * body.ageYears)
            switch body.gender {
            case .male: return male
            case .female: return female
            // Harris-Benedict has two whole equations rather than one sex term, so the midpoint
            // here is the average of the two, as Mifflin-St Jeor's -78 is of +5 and -161.
            case .preferNotToSay: return (male + female) / 2
            }
        case .cunningham:
            guard let bodyFat = body.bodyFatPercentage, bodyFat > 0, bodyFat < 100 else {
                return mifflinStJeor(body: body)
            }
            let fatFreeMassKg = body.weightKg * (1 - (bodyFat / 100))
            return 500 + (22 * fatFreeMassKg)
        }
    }

    static func mifflinStJeor(body: Body) -> Double {
        (10 * body.weightKg) + (6.25 * body.heightCm) - (5 * body.ageYears) + body.gender.mifflinStJeorCoefficient
    }

    /// Resting rate × PAL, never below `minimumTotalKcal`.
    static func estimate(equation: BMREquation, body: Body, activity: ActivityLevel) -> Estimate {
        let resting = restingKcal(equation: equation, body: body)
        let multiplier = activityMultiplier(for: activity)
        return Estimate(
            restingKcal: resting,
            activityMultiplier: multiplier,
            totalKcal: max(minimumTotalKcal, resting * multiplier)
        )
    }
}
