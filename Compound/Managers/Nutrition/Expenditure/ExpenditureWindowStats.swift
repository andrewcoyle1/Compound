//
//  ExpenditureWindowStats.swift
//  Compound
//

import Foundation

/// Everything the engine needs to know about one day's window, worked out once.
///
/// Split out of `ExpenditureEngine` because the sufficiency test, the energy balance and the step
/// nowcast all read the same handful of derived figures, and threading them through as arguments
/// made every signature longer than the rule it was implementing.
struct ExpenditureWindowStats {

    typealias Constants = ExpenditureEngine.Constants

    /// The energy balance over the window: what the logs say the body spent.
    struct EnergyBalance: Equatable {
        let rawExpenditure: Double
        let weeklyTrendChangeKg: Double
    }

    private let window: [DailySample]
    private let trendByDay: [Date: Double]
    private let calendar: Calendar

    let loggedDays: Int
    let weighInCount: Int
    /// Sample days actually present in the window, which is what the fractions are taken of.
    let daysPresent: Int
    let trendWeightKg: Double?

    init(window: [DailySample], trend: [Date: Double], calendar: Calendar) {
        self.window = window
        self.trendByDay = trend
        self.calendar = calendar
        self.loggedDays = window.filter { $0.intakeKcal != nil && !$0.isExcluded }.count
        self.weighInCount = window.filter { $0.weightKg != nil }.count
        self.daysPresent = window.count
        self.trendWeightKg = window.last.flatMap { trend[$0.day] }
    }

    // MARK: - Sufficiency

    /// The window is sufficient when there is enough of every kind of evidence to trust it.
    ///
    /// All four guards are about the same thing from different sides: an energy balance read off a
    /// fortnight of half-logged days and two weigh-ins a day apart is arithmetic, not a measurement.
    func isSufficient(daysSinceFirstSample: Int) -> Bool {
        daysSinceFirstSample >= Constants.minWindowDays
            && Double(loggedDays) >= Constants.minLoggedFraction * Double(daysPresent)
            && weighInCount >= Constants.minWeighIns
            && weighInSpanDays >= Constants.minWeighInSpanDays
    }

    /// The gap between the first and last weigh-in in the window, in days.
    var weighInSpanDays: Int {
        let days = window.filter { $0.weightKg != nil }.map(\.day)
        guard let first = days.first, let last = days.last else { return 0 }
        return calendar.dateComponents([.day], from: first, to: last).day ?? 0
    }

    // MARK: - Energy balance

    /// `intake − (trend change in energy)`, which is what the body must have spent.
    ///
    /// Unlogged days are assumed to look like the logged ones; that assumption is exactly what
    /// `minLoggedFraction` is guarding, and v1 does not try to impute them any other way.
    func energyBalance() -> EnergyBalance? {
        let intakes = window.filter { !$0.isExcluded }.compactMap(\.intakeKcal)
        guard !intakes.isEmpty else { return nil }
        let meanIntake = intakes.reduce(0, +) / Double(intakes.count)

        let trendDays = window.map(\.day).filter { trendByDay[$0] != nil }
        guard let firstDay = trendDays.first, let lastDay = trendDays.last,
              let firstTrend = trendByDay[firstDay], let lastTrend = trendByDay[lastDay] else { return nil }
        let spanDays = calendar.dateComponents([.day], from: firstDay, to: lastDay).day ?? 0
        guard spanDays > 0 else { return nil }

        let deltaTrendKg = lastTrend - firstTrend
        let dailySurplus = deltaTrendKg * Constants.kcalPerKg / Double(spanDays)
        let raw = meanIntake - dailySurplus
        guard raw.isFinite else { return nil }

        return EnergyBalance(
            rawExpenditure: raw,
            weeklyTrendChangeKg: deltaTrendKg * 7 / Double(spanDays)
        )
    }

    // MARK: - Step nowcast

    /// How far the last week's steps sit above or below the window's, priced in kcal.
    ///
    /// Additive for display and proposals only — never fed back into the running estimate. The
    /// energy balance already has the window's steps in it; this only anticipates a change in the
    /// last week that a 28-day window has not absorbed yet. Double-counting it would chase noise.
    func stepNowcast() -> Double {
        let stepDays = window.filter { $0.steps != nil }
        guard stepDays.count * 2 >= daysPresent, !stepDays.isEmpty,
              let weightKg = trendWeightKg else { return 0 }

        let recent = stepDays.suffix(Constants.nowcastRecentDays).map { Double($0.steps ?? 0) }
        guard !recent.isEmpty else { return 0 }
        let recentMean = recent.reduce(0, +) / Double(recent.count)
        let windowMean = stepDays.map { Double($0.steps ?? 0) }.reduce(0, +) / Double(stepDays.count)

        let raw = (recentMean - windowMean) * Constants.kcalPerStepPerKg * weightKg
        return raw.clamped(
            to: -Constants.maxStepNowcastKcal...Constants.maxStepNowcastKcal,
            whenNotFinite: 0
        )
    }

    // MARK: - Output

    func estimate(
        day: Date,
        kcal: Double,
        source: ExpenditureEstimate.Source,
        isProvisional: Bool,
        weeklyTrendChangeKg: Double? = nil,
        stepAdjustmentKcal: Double = 0
    ) -> ExpenditureEstimate {
        ExpenditureEstimate(
            day: day,
            kcal: kcal.rounded(),
            source: source,
            isProvisional: isProvisional,
            trendWeightKg: trendWeightKg,
            weeklyTrendChangeKg: weeklyTrendChangeKg,
            loggedDays: loggedDays,
            weighInCount: weighInCount,
            windowDays: daysPresent,
            stepAdjustmentKcal: stepAdjustmentKcal
        )
    }
}
