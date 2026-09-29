//
//  WorkoutConsistencyPresenter.swift
//  DialedIn
//

import SwiftUI

@Observable
@MainActor
class WorkoutConsistencyPresenter {

    private let interactor: WorkoutInteractor
    private let router: WorkoutRouter
    private let calendar = Calendar.current

    private(set) var cachedEntries: [WorkoutEntry] = []

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
            // A rest day is written ahead of time by the training program, already ended and dated
            // into the future. Counted as a workout it put tomorrow at the top of the history as a
            // zero-set session and shaded grid squares for days that had not happened.
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
    }
}

extension WorkoutConsistencyPresenter: @MainActor MetricDetailPresenter {
    typealias Entry = WorkoutEntry

    var entries: [WorkoutEntry] {
        cachedEntries
    }

    var timeSeries: [TimeSeries] {
        []
    }

    /// One point per completed workout, so a day's squares shade by how many were done and the
    /// callout can say "2 workouts". Every session there is: the grid scrolls back through them.
    var contributionSeries: TimeSeries? {
        guard !cachedEntries.isEmpty else { return nil }
        return TimeSeries(
            name: "Workouts",
            data: cachedEntries.map { TimeSeriesDatapoint(id: $0.id, date: $0.date, value: 1) }
        )
    }

    var configuration: MetricConfiguration {
        MetricConfiguration(
            title: String(localized: "Workouts"),
            analyticsName: "WorkoutConsistencyView",
            yAxisSuffix: "",
            seriesNames: ["Sets"],
            showsAddButton: true,
            sectionHeader: "Workout History",
            emptyStateMessage: "No completed workouts",
            chartColor: .orange,
            addActionTitle: "Start Workout",
            addActionSystemImage: "figure.run",
            contributionUnit: "workouts"
        )
    }

    func onAppear() async {
        loadData()
    }

    func onAddPressed() {
        router.showWorkoutsView(delegate: WorkoutsDelegate())
    }

}
