//
//  ExpenditureEngine.swift
//  Compound
//

import Foundation

/// Turns what the user logged into a day-by-day expenditure estimate.
///
/// Pure by construction: no managers, no `@MainActor`, no `Date()`. The caller passes the samples,
/// the formula prior, the settings, today and the calendar; the engine replays them from the first
/// sample and hands back one estimate per day. That is what makes every rule in
/// `docs/specs/adaptive-expenditure.md` testable without a simulator or a sign-in.
///
/// The formula TDEE stays the prior — the figure before there is enough data, and the band the
/// adaptive figure is clamped into. Nothing here replaces `NutritionManager.estimateTDEE`.
struct ExpenditureEngine {

    /// Every tunable in one place, so the tests and a future v2 can both see them.
    enum Constants {
        /// Energy content of a kilogram of body-mass change; the conventional figure.
        static let kcalPerKg: Double = 7700
        /// EMA smoothing for scale weight; roughly a ten-day time constant.
        static let trendAlpha: Double = 0.10
        /// A weigh-in further than this from the trend is clamped to the band before it updates it.
        static let outlierFraction: Double = 0.025
        /// The energy-balance regression window.
        static let windowDays: Int = 28
        /// Fewer days than this since the first sample and the estimate stays provisional.
        static let minWindowDays: Int = 14
        static let minLoggedFraction: Double = 0.5
        static let minWeighIns: Int = 4
        static let minWeighInSpanDays: Int = 7
        /// Daily blend of the raw estimate into the running estimate.
        static let blendAlpha: Double = 0.30
        /// The running estimate never moves more than this in a day.
        static let maxDailyStepKcal: Double = 150
        static let priorBoundLow: Double = 0.60
        static let priorBoundHigh: Double = 1.60
        /// Step nowcast: kcal per step per kg (about 35 kcal per 1000 steps at 70 kg).
        static let kcalPerStepPerKg: Double = 0.0005
        static let maxStepNowcastKcal: Double = 300
        /// The trailing window the nowcast compares against the whole window.
        static let nowcastRecentDays: Int = 7
        /// How many weigh-in days the trend seed averages before the EMA takes over.
        static let trendSeedWeighIns: Int = 7
    }

    // MARK: - Public API

    /// One estimate per replay day, ascending, ending on `today`.
    ///
    /// Recomputed from scratch every call. It is O(days x window), which for years of logging is
    /// still nothing, and it buys the engine out of ever needing a migration.
    func history(
        samples: [DailySample],
        priorKcal: Double,
        settings: NutritionStrategySettings,
        today: Date,
        calendar: Calendar
    ) -> [ExpenditureEstimate] {
        switch settings.algorithmVersion {
        case .version1:
            return historyV1(
                samples: samples,
                priorKcal: priorKcal,
                settings: settings,
                today: today,
                calendar: calendar
            )
        }
    }

    /// The estimate for `today`, which is the last day of the history.
    func current(
        samples: [DailySample],
        priorKcal: Double,
        settings: NutritionStrategySettings,
        today: Date,
        calendar: Calendar
    ) -> ExpenditureEstimate {
        let days = history(
            samples: samples,
            priorKcal: priorKcal,
            settings: settings,
            today: today,
            calendar: calendar
        )
        return days.last ?? Self.priorEstimate(day: calendar.startOfDay(for: today), kcal: priorKcal)
    }

    // MARK: - Version 1

    private func historyV1(
        samples: [DailySample],
        priorKcal: Double,
        settings: NutritionStrategySettings,
        today: Date,
        calendar: Calendar
    ) -> [ExpenditureEstimate] {
        let startOfToday = calendar.startOfDay(for: today)
        let usable = Self.usableSamples(samples, settings: settings, today: startOfToday, calendar: calendar)
        let prior = priorKcal.isFinite ? priorKcal : 0

        guard let firstDay = usable.first?.day else {
            return [Self.priorEstimate(day: startOfToday, kcal: prior, fixed: settings.calculationMode == .fixed)]
        }

        // `uniqueKeysWithValues` would trap on two samples for one day. Nothing the app builds
        // produces that — `ExpenditureSampleBuilder` folds by day — but this is a public entry
        // point taking a plain array, and a trap is not an acceptable answer to a bad argument.
        // The later sample wins, which is the same rule the builder's own merge follows.
        let byDay = Dictionary(usable.map { ($0.day, $0) }, uniquingKeysWith: { _, later in later })
        let trend = Self.trendWeights(usable, calendar: calendar)
        var running = prior
        var estimates: [ExpenditureEstimate] = []

        var day = firstDay
        while day <= startOfToday {
            let window = Self.window(endingBefore: day, byDay: byDay, calendar: calendar)
            let estimate = estimate(
                day: day,
                window: window,
                trend: trend,
                firstDay: firstDay,
                prior: prior,
                running: &running,
                settings: settings,
                calendar: calendar
            )
            estimates.append(estimate)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return estimates
    }

    // swiftlint:disable:next function_parameter_count
    private func estimate(
        day: Date,
        window: [DailySample],
        trend: [Date: Double],
        firstDay: Date,
        prior: Double,
        running: inout Double,
        settings: NutritionStrategySettings,
        calendar: Calendar
    ) -> ExpenditureEstimate {
        let stats = ExpenditureWindowStats(window: window, trend: trend, calendar: calendar)

        guard settings.calculationMode != .fixed else {
            return stats.estimate(day: day, kcal: prior, source: .fixed, isProvisional: false)
        }

        // The count runs to the day before `day`, because `day` itself has no sample yet: the
        // window ends yesterday, and so does the evidence.
        let daysSinceFirst = Self.dayCount(from: firstDay, to: day, calendar: calendar) - 1
        guard stats.isSufficient(daysSinceFirstSample: daysSinceFirst),
              let balance = stats.energyBalance() else {
            return stats.estimate(day: day, kcal: running, source: .prior, isProvisional: true)
        }

        running = Self.blend(running: running, raw: balance.rawExpenditure, prior: prior)
        let nowcast = settings.stepInformedUpdates
            ? stats.stepNowcast()
            : 0

        return stats.estimate(
            day: day,
            kcal: running + nowcast,
            source: .adaptive,
            isProvisional: false,
            weeklyTrendChangeKg: balance.weeklyTrendChangeKg,
            stepAdjustmentKcal: nowcast
        )
    }

    /// One blend step, capped in kcal per day and then held inside the band around the prior.
    ///
    /// The blend, not the raw figure, is what the user sees: one bad week of logging moves the
    /// number slowly and moves it back just as slowly.
    private static func blend(running: Double, raw: Double, prior: Double) -> Double {
        let step = (Constants.blendAlpha * (raw - running))
            .clamped(to: -Constants.maxDailyStepKcal...Constants.maxDailyStepKcal, whenNotFinite: 0)
        let blended = running + step
        guard prior > 0 else { return blended }
        return blended.clamped(
            to: (prior * Constants.priorBoundLow)...(prior * Constants.priorBoundHigh),
            whenNotFinite: prior
        )
    }

    // MARK: - Samples

    /// Start-of-day, sorted, today and later dropped, and anything before the calculation start
    /// date discarded so the replay begins fresh from that day.
    private static func usableSamples(
        _ samples: [DailySample],
        settings: NutritionStrategySettings,
        today: Date,
        calendar: Calendar
    ) -> [DailySample] {
        let startDate = settings.calculationStartDate.map { calendar.startOfDay(for: $0) }
        return samples
            .map { sample in
                DailySample(
                    day: calendar.startOfDay(for: sample.day),
                    intakeKcal: sample.intakeKcal,
                    weightKg: sample.weightKg,
                    steps: sample.steps,
                    isExcluded: sample.isExcluded
                )
            }
            .filter { $0.day < today }
            .filter { sample in startDate.map { sample.day >= $0 } ?? true }
            .sorted { $0.day < $1.day }
    }

    /// The `windowDays` days ending the day before `day`, intersected with the samples there are.
    private static func window(
        endingBefore day: Date,
        byDay: [Date: DailySample],
        calendar: Calendar
    ) -> [DailySample] {
        var window: [DailySample] = []
        for offset in stride(from: -Constants.windowDays, through: -1, by: 1) {
            guard let date = calendar.date(byAdding: .day, value: offset, to: day),
                  let sample = byDay[date] else { continue }
            window.append(sample)
        }
        return window
    }

    /// Inclusive count of days, so one day to itself is 1.
    static func dayCount(from start: Date, to end: Date, calendar: Calendar) -> Int {
        (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
    }

    // MARK: - Trend weight

    /// The exponentially smoothed scale weight, one value per sample day.
    ///
    /// Seeded from the first several weigh-ins rather than the very first, so a single odd reading
    /// on day one does not anchor a month of estimates. Days without a weigh-in carry the trend
    /// forward so the chart always has a value; days before the first weigh-in have none.
    private static func trendWeights(_ samples: [DailySample], calendar: Calendar) -> [Date: Double] {
        let weighIns = samples.compactMap { sample in sample.weightKg.map { (day: sample.day, kg: $0) } }
        guard let first = weighIns.first else { return [:] }

        let seedValues = weighIns.prefix(Constants.trendSeedWeighIns).map(\.kg)
        var trend = seedValues.reduce(0, +) / Double(seedValues.count)

        var result: [Date: Double] = [:]
        var seeded = false
        for sample in samples {
            if let weight = sample.weightKg {
                if seeded {
                    let low = trend * (1 - Constants.outlierFraction)
                    let high = trend * (1 + Constants.outlierFraction)
                    let clamped = min(max(weight, low), high)
                    trend += Constants.trendAlpha * (clamped - trend)
                } else if sample.day == first.day {
                    seeded = true
                }
            }
            guard seeded else { continue }
            result[sample.day] = trend
        }
        return result
    }

    // MARK: - Fallback

    private static func priorEstimate(day: Date, kcal: Double, fixed: Bool = false) -> ExpenditureEstimate {
        ExpenditureEstimate(
            day: day,
            kcal: kcal.rounded(),
            source: fixed ? .fixed : .prior,
            isProvisional: !fixed,
            trendWeightKg: nil,
            weeklyTrendChangeKg: nil,
            loggedDays: 0,
            weighInCount: 0,
            windowDays: 0,
            stepAdjustmentKcal: 0
        )
    }
}
