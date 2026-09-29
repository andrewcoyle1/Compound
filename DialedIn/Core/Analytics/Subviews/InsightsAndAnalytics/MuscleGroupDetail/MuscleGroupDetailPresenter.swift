//
//  MuscleGroupDetailPresenter.swift
//  DialedIn
//
//  Created by Cursor on 07/02/2026.
//

import SwiftUI

@Observable
@MainActor
class MuscleGroupDetailPresenter {

    private let interactor: MuscleGroupDetailInteractor
    private let router: MuscleGroupDetailRouter
    private let muscle: Muscles
    private let calendar = Calendar.current

    private(set) var cachedEntries: [MuscleGroupDetailEntry] = []
    private(set) var cachedTimeSeries: [TimeSeries] = []

    var allExercises: [ExerciseModel] {
        interactor.allExercises
    }
    
    var workoutSessions: [WorkoutSessionModel] {
        interactor.workoutSessions
    }
    
    init(interactor: MuscleGroupDetailInteractor, router: MuscleGroupDetailRouter, muscle: Muscles) {
        self.interactor = interactor
        self.router = router
        self.muscle = muscle
    }

    func loadData() async {
        let completed = workoutSessions
            .filter { $0.endedAt != nil }
            .sorted { ($0.endedAt ?? .distantPast) > ($1.endedAt ?? .distantPast) }
        let templateIds = Set(completed.flatMap { $0.exercises.map(\.templateId) })
        let templates: [String: ExerciseModel]
        if templateIds.isEmpty {
            templates = [:]
        } else {
            templates = Dictionary(uniqueKeysWithValues: allExercises.map { ($0.id, $0) })
        }
        let setsByDay = computeSetsByDay(completed: completed, templates: templates)
        let sortedDays = setsByDay.keys.sorted()
        cachedEntries = sortedDays.reversed().map { day in
            MuscleGroupDetailEntry(
                id: day.timeIntervalSince1970.description,
                date: day,
                sets: setsByDay[day] ?? 0
            )
        }
        cachedTimeSeries = [
            TimeSeries(
                name: "Sets",
                data: sortedDays.map { day in
                    TimeSeriesDatapoint(
                        id: day.timeIntervalSince1970.description,
                        date: day,
                        value: setsByDay[day] ?? 0
                    )
                }
            )
        ]
    }

    private func computeSetsByDay(
        completed: [WorkoutSessionModel],
        templates: [String: ExerciseModel]
    ) -> [Date: Double] {
        var setsByDay: [Date: Double] = [:]
        let startOfDay: (Date) -> Date = { self.calendar.startOfDay(for: $0) }
        for session in completed {
            let sessionDate = session.endedAt ?? session.dateCreated
            let day = startOfDay(sessionDate)
            for exercise in session.exercises {
                guard let template = templates[exercise.templateId],
                      let sets = MuscleVolume.weightedSets(exercise, template: template)[muscle] else { continue }
                setsByDay[day, default: 0] += sets
            }
        }
        return setsByDay
    }

    func onDismissPressed() {
        router.dismissScreen()
    }
}

extension MuscleGroupDetailPresenter: @MainActor MetricDetailPresenter {
    typealias Entry = MuscleGroupDetailEntry

    var entries: [MuscleGroupDetailEntry] {
        cachedEntries
    }

    var timeSeries: [TimeSeries] {
        cachedTimeSeries
    }

    var configuration: MetricConfiguration {
        MetricConfiguration(
            title: muscle.name,
            analyticsName: "MuscleGroupDetailView",
            yAxisSuffix: " sets",
            seriesNames: ["Sets"],
            showsAddButton: true,
            sectionHeader: "Daily Sets",
            emptyStateMessage: "No sets for \(muscle.name) in recent workouts",
            chartColor: .blue,
            chartType: .bar,
            addActionTitle: "Start Workout",
            addActionSystemImage: "figure.run"
        )
    }

    func onAppear() async {
        await loadData()
    }

    func onAddPressed() {
        // Sets do come from workouts — so this starts one rather than doing nothing.
        router.showWorkoutsView(delegate: WorkoutsDelegate())
    }
}
