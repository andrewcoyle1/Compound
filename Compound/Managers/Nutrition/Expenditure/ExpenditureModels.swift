//
//  ExpenditureModels.swift
//  Compound
//

import Foundation

/// One calendar day of the three things the expenditure engine reads.
///
/// A day with meal logs but no calories in them is `intakeKcal == 0`, not `nil`: the user logged,
/// they just ate nothing the app knows about. Only a day with no meal log at all is unlogged.
struct DailySample: Equatable, Sendable {
    /// Start of day, in the calendar the samples were built with.
    let day: Date
    let intakeKcal: Double?
    /// The day's first weigh-in.
    let weightKg: Double?
    let steps: Int?
    /// The day's intake is not to be read as a measurement: partially logged, or inside a logging
    /// break. It counts as unlogged, but its weigh-in still feeds the trend — the scale did not stop
    /// being true because the food log did.
    let isExcluded: Bool
    /// The user said they fasted. A low intake on such a day is real, so the engine does not read
    /// it as a partly logged day.
    let isFastingDay: Bool

    init(
        day: Date,
        intakeKcal: Double? = nil,
        weightKg: Double? = nil,
        steps: Int? = nil,
        isExcluded: Bool = false,
        isFastingDay: Bool = false
    ) {
        self.day = day
        self.intakeKcal = intakeKcal
        self.weightKg = weightKg
        self.steps = steps
        self.isExcluded = isExcluded
        self.isFastingDay = isFastingDay
    }
}

/// The engine's answer for one day. Deterministic given its inputs, so nothing here is persisted.
struct ExpenditureEstimate: Equatable, Sendable {

    /// Where the day's figure came from, which is what the status line on the settings screen says.
    enum Source: String, Equatable, Sendable {
        /// The formula estimate, shown while the filter is still calibrating.
        case prior
        /// The filter's estimate from logged intake and the weight trend.
        case adaptive
        /// `calculationMode == .fixed`; the user asked for the number to stand still.
        case fixed
    }

    let day: Date
    /// What the app uses, rounded to the nearest kilocalorie. The formula prior while calibrating.
    let kcal: Double
    let source: Source
    /// True while the filter is still calibrating, so the UI can say the figure is the formula's.
    let isProvisional: Bool
    /// The filter's trend weight as at the day before.
    let trendWeightKg: Double?
    /// The trend's rate, 7·(E − T)/ρ; nil until there are enough weigh-ins to read one.
    let weeklyTrendChangeKg: Double?
    /// Complete logged days in the window: logged, not excluded, not read as partial.
    let loggedDays: Int
    let weighInCount: Int
    /// The number of sample days actually present in the window, not the constant.
    let windowDays: Int
    /// The step nowcast already included in `kcal`; 0 unless it applied.
    let stepAdjustmentKcal: Double
    /// The filter's SD of expenditure, √P_TT. Nil before the first weigh-in and in Fixed mode.
    let sdKcal: Double?
    /// The SD of `weeklyTrendChangeKg`.
    let weeklyTrendChangeSDKg: Double?
    /// Mean intake over the complete logged days of the last week, for the adherence check.
    let recentIntakeKcal: Double?

    init(
        day: Date,
        kcal: Double,
        source: Source,
        isProvisional: Bool,
        trendWeightKg: Double?,
        weeklyTrendChangeKg: Double?,
        loggedDays: Int,
        weighInCount: Int,
        windowDays: Int,
        stepAdjustmentKcal: Double,
        sdKcal: Double? = nil,
        weeklyTrendChangeSDKg: Double? = nil,
        recentIntakeKcal: Double? = nil
    ) {
        self.day = day
        self.kcal = kcal
        self.source = source
        self.isProvisional = isProvisional
        self.trendWeightKg = trendWeightKg
        self.weeklyTrendChangeKg = weeklyTrendChangeKg
        self.loggedDays = loggedDays
        self.weighInCount = weighInCount
        self.windowDays = windowDays
        self.stepAdjustmentKcal = stepAdjustmentKcal
        self.sdKcal = sdKcal
        self.weeklyTrendChangeSDKg = weeklyTrendChangeSDKg
        self.recentIntakeKcal = recentIntakeKcal
    }

    /// The two-sided 80% normal quantile: an 80% interval is the estimate ± 1.28 SD.
    static let eightyPercentZ: Double = 1.28

    /// The 80% interval, rounded, once the estimate is adaptive.
    var likelyRange: ClosedRange<Double>? {
        // Finite only: callers print the bounds through `Int(_:)`, which traps on NaN.
        guard source == .adaptive, let sdKcal, sdKcal.isFinite, kcal.isFinite else { return nil }
        let half = Self.eightyPercentZ * sdKcal
        return (kcal - half).rounded()...(kcal + half).rounded()
    }

    /// How sure the estimate is, for a badge: design choice — tune by replay.
    enum Confidence: Sendable {
        case calibrating, low, medium, high
    }

    /// High below 120 kcal SD, medium to 250, low above; calibrating until adaptive.
    var confidence: Confidence {
        guard source == .adaptive, let sdKcal else { return .calibrating }
        if sdKcal < 120 { return .high }
        if sdKcal <= 250 { return .medium }
        return .low
    }
}
