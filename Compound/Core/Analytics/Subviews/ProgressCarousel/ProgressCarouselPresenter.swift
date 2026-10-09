//
//  ProgressCarouselPresenter.swift
//  Compound
//

import SwiftUI

/// The pages after the weekly target grid at the top of the Progress tab: today's nutrition, a
/// month's energy balance, this week's training and recent records. Each has a toggle choosing
/// what it compares against.
@Observable
@MainActor
class ProgressCarouselPresenter {
    private let interactor: ProgressCarouselInteractor
    private let calendar = Calendar.current

    var dailyShowsRemaining = false
    var energyComparison: EnergyComparison = .expenditure
    var workoutScope: WorkoutScope = .activeProgram
    var recordKind: ProgressCarouselMetrics.RecordKind = .volume

    /// Read in `load()`, as the weekly grid reads its days: the nutrition reads are local but throw.
    private(set) var todayTotals: DailyMacroTarget?
    private(set) var todayTarget: DailyMacroTarget?
    private(set) var energyDays: [ProgressCarouselMetrics.EnergyDay] = []

    static let energyDayCount = 30

    init(interactor: ProgressCarouselInteractor) {
        self.interactor = interactor
    }

    func load() async {
        let today = calendar.startOfDay(for: Date())
        // The adaptive estimate day by day, carried on through a logging break and the formula
        // before the history starts (`EnergyBalanceSummary`).
        let expenditure = EnergyBalanceSummary.expenditureLookup(
            history: interactor.expenditureHistory,
            formulaKcal: interactor.estimateTDEE(user: interactor.currentUser),
            calendar: calendar
        )
        var days: [ProgressCarouselMetrics.EnergyDay] = []
        for offset in stride(from: Self.energyDayCount - 1, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            days.append(ProgressCarouselMetrics.EnergyDay(
                date: date,
                intake: totals(on: date)?.calories ?? 0,
                expenditure: expenditure(date),
                target: await target(on: date)?.calories
            ))
        }
        energyDays = days
        todayTotals = totals(on: today)
        todayTarget = await target(on: today)
    }

    private func totals(on date: Date) -> DailyMacroTarget? {
        do {
            return try interactor.getDailyTotals(dayKey: date.dayKey)
        } catch {
            interactor.trackEvent(event: Event.loadFail(error: error))
            return nil
        }
    }

    private func target(on date: Date) async -> DailyMacroTarget? {
        guard let userId = interactor.userId else { return nil }
        do {
            return try await interactor.getDailyTarget(for: date, userId: userId)
        } catch {
            interactor.trackEvent(event: Event.loadFail(error: error))
            return nil
        }
    }

    // MARK: - Daily nutrition

    var caloriesConsumed: Double { todayTotals?.calories ?? 0 }

    /// Nil without a diet plan, or with one that sets no calories.
    var caloriesTarget: Double? {
        guard let calories = todayTarget?.calories, calories > 0 else { return nil }
        return calories
    }

    var caloriesRemaining: Double? {
        caloriesTarget.map { MacroHeader.remaining(total: caloriesConsumed, target: $0, showOverages: false) }
    }

    /// How far round the gauge today's eating has come, 0...1.
    var caloriesFraction: Double {
        guard let caloriesTarget else { return 0 }
        return min(caloriesConsumed / caloriesTarget, 1)
    }

    struct MacroRow: Identifiable {
        let macro: Macro
        let consumed: Double
        let target: Double?

        var id: String { macro.title }

        var fraction: Double {
            guard let target, target > 0 else { return 0 }
            return min(consumed / target, 1)
        }
    }

    var macroRows: [MacroRow] {
        [
            (Macro.protein, \DailyMacroTarget.proteinGrams),
            (Macro.fat, \DailyMacroTarget.fatGrams),
            (Macro.carbs, \DailyMacroTarget.carbGrams)
        ].map { macro, keyPath in
            MacroRow(macro: macro, consumed: todayTotals?[keyPath: keyPath] ?? 0, target: todayTarget?[keyPath: keyPath])
        }
    }

    // MARK: - Energy balance

    enum EnergyComparison: CaseIterable, Hashable {
        case expenditure
        case targets

        var title: String {
            switch self {
            case .expenditure: return String(localized: "Expenditure")
            case .targets: return String(localized: "Targets")
            }
        }

        @MainActor var colour: Color {
            switch self {
            case .expenditure: return EnergyBalanceChart.expenditureColor
            case .targets: return Color.Metric.goalProgress
            }
        }
    }

    var energyAverages: (intake: Double, comparison: Double)? {
        ProgressCarouselMetrics.averages(energyDays) { day in
            energyComparison == .expenditure ? day.expenditure : day.target
        }
    }

    var energyIntakeSeries: TimeSeries {
        TimeSeries(name: "Intake", data: energyDays.map {
            TimeSeriesDatapoint(id: "intake-\($0.date.dayKey)", date: $0.date, value: $0.intake)
        })
    }

    var energyComparisonSeries: TimeSeries {
        TimeSeries(name: "Comparison", data: energyDays.compactMap { day in
            guard let value = energyComparison == .expenditure ? day.expenditure : day.target else { return nil }
            return TimeSeriesDatapoint(id: "comparison-\(day.date.dayKey)", date: day.date, value: value)
        })
    }

    // MARK: - Weekly workouts

    enum WorkoutScope: CaseIterable, Hashable {
        case activeProgram
        case allWorkouts

        var title: String {
            switch self {
            case .activeProgram: return String(localized: "Active Program")
            case .allWorkouts: return String(localized: "All Workouts")
            }
        }
    }

    var hasActiveProgram: Bool { interactor.activeMesocycle != nil }

    /// This calendar week's finished sessions, through the same weekly rule the feed and circles use.
    var workoutTally: ProgressCarouselMetrics.WorkoutTally {
        guard let userId = interactor.userId else { return .init(muscles: 0, sets: 0, exercises: 0) }
        var week = WorkoutSessionHighlights.sessions(of: userId, inWeekOf: Date(), history: interactor.workoutSessions, calendar: calendar)
        if workoutScope == .activeProgram, let mesocycle = interactor.activeMesocycle {
            week = week.filter { $0.mesocycleId == mesocycle.id }
        }
        let exercises = Dictionary(interactor.allExercises.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return ProgressCarouselMetrics.tally(sessions: week, exercises: exercises)
    }

    /// One microcycle of the active mesocycle; nil without one.
    var workoutTarget: ProgressCarouselMetrics.WorkoutTally? {
        interactor.activeMesocycle.map(ProgressCarouselMetrics.target(of:))
    }

    // MARK: - Recent records

    struct RecordRow: Identifiable {
        let id: String
        let name: String
        /// Against the largest record shown, 0...1.
        let fraction: Double
        let valueText: String
    }

    var recordRows: [RecordRow] {
        let userId = interactor.userId
        let sessions = interactor.workoutSessions.filter { $0.authorId == userId }
        let records = ProgressCarouselMetrics.recentRecords(recordKind, sessions: sessions)
        let top = records.map(\.value).max() ?? 0
        return records.map { record in
            RecordRow(
                id: record.templateId,
                name: record.name,
                fraction: top > 0 ? record.value / top : 0,
                valueText: recordText(record)
            )
        }
    }

    private func recordText(_ record: ProgressCarouselMetrics.Record) -> String {
        switch recordKind {
        case .reps:
            return Format.reps(Int(record.value))
        case .volume, .oneRepMax:
            return Format.weight(kg: record.value, unit: interactor.getPreference(templateId: record.templateId).weightUnit)
        }
    }

    enum Event: LoggableEvent {
        case loadFail(error: Error)

        var eventName: String { "ProgressCarousel_Load_Fail" }

        var parameters: [String: Any]? {
            switch self {
            case .loadFail(let error): return error.eventParameters
            }
        }

        var type: LogType { .warning }
    }
}

extension ProgressCarouselMetrics.RecordKind {
    var title: String {
        switch self {
        case .volume: return String(localized: "Volume")
        case .reps: return String(localized: "Reps")
        case .oneRepMax: return String(localized: "1-RM")
        }
    }
}
