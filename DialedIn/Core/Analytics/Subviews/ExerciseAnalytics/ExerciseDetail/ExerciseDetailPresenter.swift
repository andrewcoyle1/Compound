//
//  ExerciseDetailPresenter.swift
//  DialedIn
//
//  Created by Cursor on 07/02/2026.
//

import SwiftUI

@Observable
@MainActor
class ExerciseDetailPresenter {

    private let interactor: ExerciseDetailInteractor
    private let router: ExerciseDetailRouter
    private let templateId: String
    private let name: String
    private let calendar = Calendar.current

    private(set) var cachedEntries: [ExerciseDetailEntry] = []
    private(set) var cachedTimeSeries: [TimeSeries] = []

    var workoutSessions: [WorkoutSessionModel] {
        interactor.workoutSessions
    }
    init(interactor: ExerciseDetailInteractor, router: ExerciseDetailRouter, templateId: String, name: String) {
        self.interactor = interactor
        self.router = router
        self.templateId = templateId
        self.name = name
    }

    func loadData() async {
        let completed = workoutSessions
            .filter { $0.endedAt != nil }
            .sorted { ($0.endedAt ?? .distantPast) > ($1.endedAt ?? .distantPast) }
        let oneRMByDay = computeOneRMByDay(from: completed)
        applyCachedData(oneRMByDay: oneRMByDay)
    }

    private func clearCachedData() {
        cachedEntries = []
        cachedTimeSeries = []
    }

    private func applyCachedData(oneRMByDay: [Date: Double]) {
        let sortedDays = oneRMByDay.keys.sorted()
        cachedEntries = sortedDays.reversed().map { day in
            ExerciseDetailEntry(
                id: day.timeIntervalSince1970.description,
                date: day,
                oneRMKg: oneRMByDay[day] ?? 0
            )
        }
        // Plotted in the exercise's own unit, like the rows and the axis label. The chart used to
        // plot stored kilograms under a "lbs" axis, so a 100kg bench drew at 100 beside rows
        // reading 220.5.
        let unit = weightUnit
        let seriesData = sortedDays.map { day in
            TimeSeriesDatapoint(
                id: day.timeIntervalSince1970.description,
                date: day,
                value: UnitConversion.convertWeight(oneRMByDay[day] ?? 0, to: unit)
            )
        }
        cachedTimeSeries = [TimeSeries(name: "1-RM", data: seriesData)]
    }

    private func computeOneRMByDay(from completed: [WorkoutSessionModel]) -> [Date: Double] {
        var oneRMByDay: [Date: Double] = [:]
        let startOfDay: (Date) -> Date = { self.calendar.startOfDay(for: $0) }
        for session in completed {
            let sessionDate = session.endedAt ?? session.dateCreated
            let day = startOfDay(sessionDate)
            for exercise in session.exercises where exercise.templateId == templateId {
                let best1RM = exercise.sets
                    .filter { !$0.isWarmup && $0.completedAt != nil }
                    .compactMap { set -> Double? in
                        guard let weight = set.weightKg, weight > 0 else { return nil }
                        let reps = set.reps ?? 1
                        return ExerciseOneRMAggregator.estimated1RM(weightKg: weight, reps: max(1, reps))
                    }
                    .max()
                if let oneRM = best1RM, oneRM > 0 {
                    oneRMByDay[day] = max(oneRMByDay[day] ?? 0, oneRM)
                }
            }
        }
        return oneRMByDay
    }

    func onDismissPressed() {
        router.dismissScreen()
    }
}

extension ExerciseDetailPresenter: @MainActor MetricDetailPresenter {
    typealias Entry = ExerciseDetailEntry

    var entries: [ExerciseDetailEntry] {
        cachedEntries
    }

    var timeSeries: [TimeSeries] {
        cachedTimeSeries
    }

    /// Weight unit is a per-exercise preference — the Analytics card honours it, this screen
    /// hardcoded kilograms.
    private var weightUnit: ExerciseWeightUnit {
        interactor.getPreference(templateId: templateId).weightUnit
    }

    func displayValue(for entry: ExerciseDetailEntry) -> String {
        UnitConversion.formatWeight(entry.oneRMKg, unit: weightUnit)
    }

    var configuration: MetricConfiguration {
        MetricConfiguration(
            title: name,
            analyticsName: "ExerciseDetailView",
            yAxisSuffix: " \(weightUnit.abbreviation)",
            seriesNames: ["1-RM"],
            showsAddButton: true,
            sectionHeader: "Daily 1-RM",
            emptyStateMessage: "No 1-RM data for \(name)",
            chartColor: Color.Metric.exercises,
            chartType: .line,
            addActionTitle: "Start Workout",
            addActionSystemImage: "figure.run"
        )
    }

    func onAppear() async {
        await loadData()
    }

    func onAddPressed() {
        // 1-RM is estimated from logged sets, so the way to add one is to train.
        router.showWorkoutsView(delegate: WorkoutsDelegate())
    }
}
