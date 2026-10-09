//
//  ExpenditureEngine.swift
//  Compound
//

import Foundation

/// Turns what the user logged into a day-by-day expenditure estimate.
///
/// Pure by construction: no managers, no `@MainActor`, no `Date()`. The caller passes the samples,
/// the formula prior, the settings, today and the calendar; the engine replays them from the first
/// sample through `ExpenditureFilter`, one day at a time, and hands back one estimate per day. That
/// is what makes every rule in `docs/specs/adaptive-expenditure.md` testable without a simulator.
///
/// The formula TDEE stays the prior: the filter's starting point, the figure shown while it
/// calibrates, and a sanity band. Nothing here replaces `NutritionManager.estimateTDEE`.
struct ExpenditureEngine {

    /// Every tunable in one place, so the tests and the JavaScript port can both see them.
    enum Constants {
        /// The conventional energy density, for callers that do not pass one (`EnergyDensity`).
        static let kcalPerKg: Double = EnergyDensity.conventionalKcalPerKg
        /// The window the status counts, the logged fraction and the nowcast read.
        static let windowDays: Int = 28

        // MARK: Calibration gate — design choice, tune by replay

        /// Calibrating until there are 21 days of data and 14 weigh-ins (Hall & Chow 2011 find
        /// about four weeks of daily weights are needed for a usable individual estimate)…
        static let minDays: Int = 21
        static let minWeighIns: Int = 14
        /// …the filter's SD is under 200 kcal…
        static let maxCalibratedSDKcal: Double = 200
        /// …and 80% of the window's days are completely logged.
        static let calibratedLoggedFraction: Double = 0.8

        // MARK: Intake observations — design choice, tune by replay

        /// A logged day below half the current estimate is read as partly logged and skipped,
        /// unless the user marked it as a fast.
        static let partialDayFraction: Double = 0.5
        /// σ_I is the user's own SD of logged daily intake over the last 28 days, held inside
        /// 300–500 kcal; 400 until there are seven logged days.
        static let intakeNoiseMinKcal: Double = 300
        static let intakeNoiseMaxKcal: Double = 500
        static let intakeNoiseDefaultKcal: Double = 400
        static let intakeNoiseMinDays: Int = 7
        /// Below 60% of days logged, each logged day is trusted half as much (σ_I doubled), since
        /// the unlogged days may not look like the logged ones.
        static let inflatedNoiseBelowLoggedFraction: Double = 0.6
        static let intakeNoiseInflation: Double = 2

        // MARK: Guards

        /// The figure shown never leaves 60–160% of the formula. A guard only: the filter's own
        /// state is not clamped.
        static let priorBoundLow: Double = 0.60
        static let priorBoundHigh: Double = 1.60

        // MARK: Step nowcast

        /// Net walking cost: ≈0.49 kcal/kg/km from the ACSM walking equation at 1,300–1,400 steps
        /// per km. The nowcast works on step differences, so the net (not gross) figure is right.
        static let kcalPerStepPerKg: Double = 0.0004
        static let maxStepNowcastKcal: Double = 300
        /// The trailing window the nowcast compares against the whole window.
        static let nowcastRecentDays: Int = 7

        /// The adherence check averages the last week's complete logged days.
        static let recentIntakeDays: Int = 7
    }

    // MARK: - Public API

    /// One estimate per replay day, ascending, ending on `today`.
    ///
    /// Recomputed from scratch every call. It is O(days × window), which for years of logging is
    /// still nothing, and it buys the engine out of ever needing a migration.
    ///
    /// - Parameter kcalPerKg: The energy in a kilogram of weight change, from `EnergyDensity`.
    func history(
        samples: [DailySample],
        priorKcal: Double,
        settings: NutritionStrategySettings,
        today: Date,
        calendar: Calendar,
        kcalPerKg: Double = Constants.kcalPerKg
    ) -> [ExpenditureEstimate] {
        switch settings.algorithmVersion {
        case .version1:
            var replay = Replay(
                samples: samples,
                priorKcal: priorKcal,
                settings: settings,
                today: today,
                calendar: calendar,
                kcalPerKg: kcalPerKg
            )
            return replay.run()
        }
    }

    /// The estimate for `today`, which is the last day of the history.
    func current(
        samples: [DailySample],
        priorKcal: Double,
        settings: NutritionStrategySettings,
        today: Date,
        calendar: Calendar,
        kcalPerKg: Double = Constants.kcalPerKg
    ) -> ExpenditureEstimate {
        let days = history(
            samples: samples,
            priorKcal: priorKcal,
            settings: settings,
            today: today,
            calendar: calendar,
            kcalPerKg: kcalPerKg
        )
        return days.last ?? Self.priorEstimate(day: calendar.startOfDay(for: today), kcal: priorKcal)
    }

    /// Inclusive count of days, so one day to itself is 1.
    static func dayCount(from start: Date, to end: Date, calendar: Calendar) -> Int {
        (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
    }

    static func priorEstimate(day: Date, kcal: Double, fixed: Bool = false) -> ExpenditureEstimate {
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

// MARK: - The replay

/// One run of the engine: the filter carried day by day, and the estimate read off it before each
/// day's own sample is processed, so the estimate for a day uses evidence up to the day before.
private struct Replay {

    typealias Constants = ExpenditureEngine.Constants

    let samples: [DailySample]
    let prior: Double
    let settings: NutritionStrategySettings
    let today: Date
    let calendar: Calendar
    let kcalPerKg: Double

    private var byDay: [Date: DailySample] = [:]
    private var filter: ExpenditureFilter?
    private var weighInsUsed = 0
    /// The days whose intake the filter read: logged, not excluded, not partial.
    private var completeIntakeDays: Set<Date> = []

    init(
        samples: [DailySample],
        priorKcal: Double,
        settings: NutritionStrategySettings,
        today: Date,
        calendar: Calendar,
        kcalPerKg: Double
    ) {
        self.samples = samples
        self.prior = priorKcal.isFinite ? priorKcal : 0
        self.settings = settings
        self.today = calendar.startOfDay(for: today)
        self.calendar = calendar
        self.kcalPerKg = kcalPerKg.isFinite && kcalPerKg > 0 ? kcalPerKg : Constants.kcalPerKg
    }

    mutating func run() -> [ExpenditureEstimate] {
        let usable = usableSamples()
        guard let firstDay = usable.first?.day else {
            return [ExpenditureEngine.priorEstimate(day: today, kcal: prior, fixed: settings.calculationMode == .fixed)]
        }

        // `uniqueKeysWithValues` would trap on two samples for one day. Nothing the app builds
        // produces that, but this is a public entry point taking a plain array, and a trap is not an
        // acceptable answer to a bad argument. The later sample wins, as in the builder's merge.
        byDay = Dictionary(usable.map { ($0.day, $0) }, uniquingKeysWith: { _, later in later })
        let seed = WeighInNoise.median(
            Array(usable.compactMap(\.weightKg).prefix(WeighInNoise.seedWeighIns))
        )

        var estimates: [ExpenditureEstimate] = []
        var day = firstDay
        while day <= today {
            estimates.append(estimate(day: day, firstDay: firstDay))
            if day < today {
                process(day: day, seed: seed)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return estimates
    }

    // MARK: Processing a day

    private mutating func process(day: Date, seed: Double?) {
        let sample = byDay[day]
        var isFirstFilterDay = false
        if filter != nil {
            // Copied first, as below: passing a stored property of `self` into the mutating call
            // on `self.filter` is an overlapping access on Darwin's compiler.
            let density = kcalPerKg
            filter?.predictOneDay(kcalPerKg: density)
        } else if sample?.weightKg != nil, let seed {
            // The filter starts on the first weigh-in, at the median of the first few.
            filter = ExpenditureFilter(levelKg: seed, priorKcal: prior)
            weighInsUsed = 1
            isFirstFilterDay = true
        }
        guard let sample else { return }

        if !isFirstFilterDay, let weightKg = sample.weightKg, filter != nil {
            if filter?.observeWeighIn(weightKg) == true {
                weighInsUsed += 1
            }
        }

        guard let intake = sample.intakeKcal, !sample.isExcluded else { return }
        // A logged day far below what the body spends is read as partly logged, unless it was a fast.
        let expenditure = filter?.expenditureKcal ?? prior
        if !sample.isFastingDay && intake < Constants.partialDayFraction * expenditure { return }
        completeIntakeDays.insert(day)
        if filter != nil {
            // Worked out first: reading `self` inside the mutating call on `self.filter` is an
            // overlapping access.
            let noiseSD = intakeNoise(endingOn: day)
            filter?.observeIntake(intake, sdKcal: noiseSD)
        }
    }

    /// σ_I for a logged day: the SD of the complete logged days in the 28 days ending on it, held
    /// inside 300–500 kcal, and doubled when fewer than 60% of those days are complete.
    private func intakeNoise(endingOn day: Date) -> Double {
        var values: [Double] = []
        var present = 0
        for offset in stride(from: -(Constants.windowDays - 1), through: 0, by: 1) {
            guard let date = calendar.date(byAdding: .day, value: offset, to: day),
                  let sample = byDay[date] else { continue }
            present += 1
            if completeIntakeDays.contains(date), let intake = sample.intakeKcal {
                values.append(intake)
            }
        }
        var noiseSD = Constants.intakeNoiseDefaultKcal
        if values.count >= Constants.intakeNoiseMinDays {
            noiseSD = Self.standardDeviation(values).clamped(
                to: Constants.intakeNoiseMinKcal...Constants.intakeNoiseMaxKcal,
                whenNotFinite: Constants.intakeNoiseDefaultKcal
            )
        }
        let isSparse = Double(values.count) < Constants.inflatedNoiseBelowLoggedFraction * Double(present)
        return isSparse ? noiseSD * Constants.intakeNoiseInflation : noiseSD
    }

    private static func standardDeviation(_ values: [Double]) -> Double {
        let mean = values.reduce(0, +) / Double(values.count)
        let squares = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) }
        return (squares / Double(values.count - 1)).squareRoot()
    }

    // MARK: Reading the estimate

    private func estimate(day: Date, firstDay: Date) -> ExpenditureEstimate {
        let stats = ExpenditureWindowStats(
            window: window(endingBefore: day),
            completeIntakeDays: completeIntakeDays,
            trendWeightKg: filter?.levelKg
        )
        let daysOfData = ExpenditureEngine.dayCount(from: firstDay, to: day, calendar: calendar) - 1
        let hasEnoughWeighIns = filter != nil
            && daysOfData >= Constants.minDays
            && weighInsUsed >= Constants.minWeighIns
        let rate = hasEnoughWeighIns ? filter?.dailyRate(kcalPerKg: kcalPerKg) : nil
        let sdKcal = filter?.expenditureSD

        let isFixed = settings.calculationMode == .fixed
        let isCalibrated = hasEnoughWeighIns
            && (sdKcal ?? .infinity) < Constants.maxCalibratedSDKcal
            && stats.loggedFraction >= Constants.calibratedLoggedFraction
        let shown = shownFigure(isFixed: isFixed, isCalibrated: isCalibrated, stats: stats)

        return ExpenditureEstimate(
            day: day,
            kcal: shown.kcal.rounded(),
            source: shown.source,
            isProvisional: shown.source == .prior,
            trendWeightKg: stats.trendWeightKg,
            weeklyTrendChangeKg: rate.map { $0.kgPerDay * 7 },
            loggedDays: stats.loggedDays,
            weighInCount: stats.weighInCount,
            windowDays: stats.daysPresent,
            stepAdjustmentKcal: shown.nowcast,
            sdKcal: isFixed ? nil : sdKcal,
            weeklyTrendChangeSDKg: rate.map { $0.sdKg * 7 },
            recentIntakeKcal: stats.recentIntakeKcal
        )
    }

    /// The figure shown: the prior in Fixed mode and while calibrating; otherwise the filter's T
    /// inside the 60–160% guard, plus the step nowcast when it is on.
    private func shownFigure(
        isFixed: Bool,
        isCalibrated: Bool,
        stats: ExpenditureWindowStats
    ) -> ShownFigure {
        if isFixed { return ShownFigure(kcal: prior, source: .fixed, nowcast: 0) }
        guard isCalibrated, let expenditure = filter?.expenditureKcal else {
            return ShownFigure(kcal: prior, source: .prior, nowcast: 0)
        }
        let bounded = prior > 0
            ? expenditure.clamped(
                to: (prior * Constants.priorBoundLow)...(prior * Constants.priorBoundHigh),
                whenNotFinite: prior
            )
            : expenditure
        let nowcast = settings.stepInformedUpdates ? stats.stepNowcast() : 0
        return ShownFigure(kcal: bounded + nowcast, source: .adaptive, nowcast: nowcast)
    }

    private struct ShownFigure {
        let kcal: Double
        let source: ExpenditureEstimate.Source
        let nowcast: Double
    }

    /// The `windowDays` days ending the day before `day`, intersected with the samples there are.
    private func window(endingBefore day: Date) -> [DailySample] {
        var window: [DailySample] = []
        for offset in stride(from: -Constants.windowDays, through: -1, by: 1) {
            guard let date = calendar.date(byAdding: .day, value: offset, to: day),
                  let sample = byDay[date] else { continue }
            window.append(sample)
        }
        return window
    }

    // MARK: Samples

    /// Start-of-day, sorted, today and later dropped, and anything before the calculation start
    /// date discarded so the replay begins fresh from that day.
    private func usableSamples() -> [DailySample] {
        let startDate = settings.calculationStartDate.map { calendar.startOfDay(for: $0) }
        return samples
            .map { sample in
                DailySample(
                    day: calendar.startOfDay(for: sample.day),
                    intakeKcal: sample.intakeKcal,
                    weightKg: sample.weightKg,
                    steps: sample.steps,
                    isExcluded: sample.isExcluded,
                    isFastingDay: sample.isFastingDay
                )
            }
            .filter { $0.day < today }
            .filter { sample in startDate.map { sample.day >= $0 } ?? true }
            .sorted { $0.day < $1.day }
    }
}
