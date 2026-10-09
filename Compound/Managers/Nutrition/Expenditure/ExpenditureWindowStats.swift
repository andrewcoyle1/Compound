//
//  ExpenditureWindowStats.swift
//  Compound
//

import Foundation

/// What the user logged in the 28 days before an estimate, worked out once: the counts the status
/// line shows, the logged fraction the calibration gate reads, last week's intake for the adherence
/// check, and the step nowcast.
///
/// The estimate itself comes from `ExpenditureFilter`; this only describes the window around it.
struct ExpenditureWindowStats {

    typealias Constants = ExpenditureEngine.Constants

    private let window: [DailySample]
    private let completeIntakeDays: Set<Date>

    /// Complete logged days: logged, not excluded and not read as partial.
    let loggedDays: Int
    let weighInCount: Int
    /// Sample days actually present in the window, which is what the fractions are taken of.
    let daysPresent: Int
    let trendWeightKg: Double?

    /// - Parameters:
    ///   - window: The samples in the window, oldest first.
    ///   - completeIntakeDays: The days whose intake the filter read.
    ///   - trendWeightKg: The filter's trend weight, for the step nowcast.
    init(window: [DailySample], completeIntakeDays: Set<Date>, trendWeightKg: Double?) {
        self.window = window
        self.completeIntakeDays = completeIntakeDays
        self.loggedDays = window.filter { completeIntakeDays.contains($0.day) }.count
        self.weighInCount = window.filter { $0.weightKg != nil }.count
        self.daysPresent = window.count
        self.trendWeightKg = trendWeightKg
    }

    /// Complete logged days as a share of the days present; 0 for an empty window.
    var loggedFraction: Double {
        daysPresent > 0 ? Double(loggedDays) / Double(daysPresent) : 0
    }

    /// Mean intake over the complete logged days among the last `recentIntakeDays` samples.
    var recentIntakeKcal: Double? {
        let recent = window.suffix(Constants.recentIntakeDays)
            .filter { completeIntakeDays.contains($0.day) }
            .compactMap(\.intakeKcal)
        guard !recent.isEmpty else { return nil }
        return recent.reduce(0, +) / Double(recent.count)
    }

    // MARK: - Step nowcast

    /// How far the last week's steps sit above or below the window's, priced in kcal.
    ///
    /// Additive for display and proposals only — never fed back into the filter. The filter has the
    /// window's steps in it already, through the weight; this only anticipates a change in the
    /// last week that it has not absorbed yet.
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
}
