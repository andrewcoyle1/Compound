//
//  WorkoutPresenter.swift
//  DialedIn
//
//  Created by Cursor on 07/02/2026.
//

import SwiftUI

@Observable
@MainActor
class WorkoutPresenter {

    private let interactor: WorkoutInteractor
    private let router: WorkoutRouter
    private let calendar = Calendar.current

    private(set) var cachedEntries: [WorkoutEntry] = []
    private(set) var cachedTimeSeries: [TimeSeries] = []

    var workoutSessions: [WorkoutSessionModel] {
        interactor.workoutSessions
    }
    
    init(interactor: WorkoutInteractor, router: WorkoutRouter) {
        self.interactor = interactor
        self.router = router
        rebuildCaches()
    }

    func loadData() {
        rebuildCaches()
    }

    func onDismissPressed() {
        router.dismissScreen()
    }

    private func rebuildCaches() {
            let completed = workoutSessions
                // A rest day is written ahead of time by the training program, already ended and
                // dated into the future, so it listed tomorrow above every workout actually done.
                .filter { $0.endedAt != nil && !$0.isRestDay }
                .sorted { ($0.endedAt ?? .distantPast) > ($1.endedAt ?? .distantPast) }

            cachedEntries = completed.map { session in
                let date = session.endedAt ?? session.dateCreated
                let sets = session.exercises.flatMap { $0.sets }.filter { !$0.isWarmup }.count
                let volume = session.exercises.flatMap { $0.sets }
                    .filter { !$0.isWarmup }
                    .compactMap { set -> Double? in
                        guard let weight = set.weightKg, let reps = set.reps else { return nil }
                        return weight * Double(reps)
                    }
                    .reduce(0, +)
                return WorkoutEntry(
                    id: session.id,
                    date: date,
                    name: session.name,
                    sets: sets,
                    volumeKg: volume
                )
            }

            let sortedEntries = cachedEntries.sorted { $0.date < $1.date }
            let seriesData = sortedEntries.map { entry in
                TimeSeriesDatapoint(id: entry.id, date: entry.date, value: Double(entry.sets))
            }
            cachedTimeSeries = [
                TimeSeries(name: "Sets", data: seriesData)
            ]
    }
}

extension WorkoutPresenter: @MainActor MetricDetailPresenter {
    typealias Entry = WorkoutEntry

    var entries: [WorkoutEntry] {
        cachedEntries
    }

    var timeSeries: [TimeSeries] {
        cachedTimeSeries
    }

    /// Nutrition metrics use a bar or stacked bar chart, not the contribution chart.
    var contributionSeries: TimeSeries? { nil }

    var configuration: MetricConfiguration {
        MetricConfiguration(
            title: String(localized: "Workouts"),
            analyticsName: "WorkoutsView",
            yAxisSuffix: "",
            seriesNames: ["Sets"],
            showsAddButton: true,
            sectionHeader: "Workout History",
            emptyStateMessage: "No completed workouts",
            chartColor: .orange,
            chartType: .bar,
            addActionTitle: "Start Workout",
            addActionSystemImage: "figure.run"
        )
    }

    func onAppear() async {
        loadData()
    }

    func onAddPressed() {
        // Was an empty body under a comment saying the user starts workouts from the Training
        // tab. That was true and left them to find it themselves; now it takes them.
        router.showWorkoutsView(delegate: WorkoutsDelegate())
    }

}
