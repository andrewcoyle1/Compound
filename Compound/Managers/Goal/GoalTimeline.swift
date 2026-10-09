//
//  GoalTimeline.swift
//  Compound
//
//  How long a weight goal takes, how the calorie target moves on the way, and the weight progress
//  is measured from.
//
//  - Rates are a share of body weight a week: 0.5–1.0% for losing (Helms 2014, R63; Garthe 2011,
//    R64) and 0.25–0.5% for gaining (Iraki 2019, R57). A fixed kilogram figure is a much bigger
//    ask of a 60 kg person than of a 120 kg one.
//  - The timeline is linear, weeks = distance ÷ rate, which holds because the weekly check-in
//    re-targets to keep the rate. Holding it means the target falls as weight does: expenditure
//    drops by roughly 24 kcal a day for each kilogram lost (Hall 2011, R25), so the screens say
//    the target will step down rather than imply one fixed number.
//  - Progress reads the smoothed trend weight, not the last weigh-in, so a day of water does not
//    move it (`WeightTrendCalculator`).
//

import Foundation

enum GoalTimeline {

    /// Change in daily expenditure per kilogram of body weight (Hall 2011: about 100 kJ/day per kg,
    /// roughly 24 kcal).
    static let expenditureKcalPerKg: Double = 24

    // MARK: - Rates, as a percentage of body weight a week

    static let lossMinimumPercent: Double = 0.25
    static let gainMinimumPercent: Double = 0.1
    static let maximumPercent: Double = 1.0
    /// Never faster than this, however heavy the person.
    static let absoluteMaximumKg: Double = 1.5

    /// The default loss rate for a lean person (BMI under 25), and for anyone else.
    static let leanLossDefaultPercent: Double = 0.5
    static let lossDefaultPercent: Double = 0.75
    static let gainDefaultPercent: Double = 0.25

    /// Above these, the rate screen warns. Losing faster than 0.75% a week is flagged only for lean
    /// people; gaining faster than 0.5% for everyone.
    static let leanLossWarningPercent: Double = 0.75
    static let gainWarningPercent: Double = 0.5

    /// Below 25 a person counts as lean for the default and the warning; with no height, too, so
    /// the more cautious figures apply.
    static let leanBMI: Double = 25

    static func isLean(weightKg: Double, heightCm: Double?) -> Bool {
        guard let heightCm, heightCm.isFinite, heightCm > 0, weightKg.isFinite, weightKg > 0 else { return true }
        let heightM = heightCm / 100
        return weightKg / (heightM * heightM) < leanBMI
    }

    // MARK: - Timeline

    /// Whole weeks to cover `distanceKg` at `weeklyRateKg`, rounded up. Zero when there is nothing
    /// to cover or no rate to cover it at.
    static func weeks(distanceKg: Double, weeklyRateKg: Double) -> Int {
        let weeks = (abs(distanceKg) / weeklyRateKg).rounded(.up)
        guard weeks.isFinite, weeks > 0 else { return 0 }
        return Int(weeks)
    }

    /// How far the daily target moves by the time `distanceKg` has been lost or gained, if the
    /// rate is held: about 24 kcal a day per kilogram.
    static func targetChangeKcal(distanceKg: Double) -> Double {
        abs(distanceKg) * expenditureKcalPerKg
    }

    // MARK: - Trend weight

    /// Every live weigh-in with its smoothed trend value, oldest first (`WeightTrendCalculator`).
    static func trend(of entries: [BodyMeasurementEntry]) -> [(entry: BodyMeasurementEntry, trendKg: Double)] {
        let weighIns = entries
            .filter { entry in
                guard entry.deletedAt == nil, let weightKg = entry.weightKg else { return false }
                return weightKg.isFinite && weightKg > 0
            }
            .sorted { $0.date < $1.date }
        let smoothed = WeightTrendCalculator.exponentialMovingAverage(
            data: weighIns.compactMap { entry -> (date: Date, value: Double)? in
                guard let weightKg = entry.weightKg else { return nil }
                return (date: entry.date, value: weightKg)
            }
        )
        return zip(weighIns, smoothed).map { (entry: $0, trendKg: $1.value) }
    }

    /// The trend weight at the latest weigh-in, or nil with none logged.
    static func latestTrendWeightKg(of entries: [BodyMeasurementEntry]) -> Double? {
        trend(of: entries).last?.trendKg
    }
}
