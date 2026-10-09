//
//  ProgressCarouselMetrics.swift
//  Compound
//
//  The sums behind the Progress tab's header carousel, as pure functions of the data so they can
//  be tested without a manager behind them.
//

import Foundation

enum ProgressCarouselMetrics {

    // MARK: - Weekly workouts

    struct WorkoutTally: Equatable {
        var muscles: Int
        var sets: Int
        var exercises: Int
    }

    /// What `sessions` trained: the muscles and exercises with at least one finished working set,
    /// and those sets, a left/right pair counting once as everywhere else.
    static func tally(sessions: [WorkoutSessionModel], exercises: [String: ExerciseModel]) -> WorkoutTally {
        var muscles = Set<Muscles>()
        var templateIds = Set<String>()
        var sets = 0
        for exercise in sessions.flatMap(\.exercises) {
            let done = MuscleVolume.completedWorkingSets(exercise)
            guard done > 0 else { continue }
            sets += done
            templateIds.insert(exercise.templateId)
            if let groups = exercises[exercise.templateId]?.muscleGroups {
                muscles.formUnion(groups.keys)
            }
        }
        return WorkoutTally(muscles: muscles.count, sets: sets, exercises: templateIds.count)
    }

    // ponytail: a microcycle stands in for the calendar week the card is titled with; a block whose
    // microcycle is not seven days long reads slightly off. Scale by its length if that matters.
    /// One pass through the mesocycle's days: what a full microcycle of it plans.
    static func target(of mesocycle: Mesocycle) -> WorkoutTally {
        let planned = mesocycle.workoutTemplates.flatMap(\.exercises).filter { !$0.setTargets.isEmpty }
        return WorkoutTally(
            muscles: Set(planned.flatMap { $0.exercise.muscleGroups.keys }).count,
            sets: planned.reduce(0) { $0 + $1.setTargets.count },
            exercises: Set(planned.map(\.exercise.id)).count
        )
    }

    // MARK: - Recent records

    enum RecordKind: CaseIterable, Hashable {
        /// One session's working volume for the exercise.
        case volume
        /// The most reps in one working set.
        case reps
        /// The best estimated one-rep max, by the estimate the exercise screens use
        /// (`ExerciseOneRMAggregator.estimated1RM`).
        case oneRepMax
    }

    struct Record: Equatable, Identifiable {
        let templateId: String
        let name: String
        /// Kilograms for volume and 1-RM, a count for reps.
        let value: Double
        /// When the record was set: the session that first reached `value`.
        let date: Date

        var id: String { templateId }
    }

    /// Each exercise's best `kind` across every finished session, the records set most recently
    /// first. A first-ever lift counts: it is the best there is, and without it a new user's card
    /// would stay empty until they beat their own first workout.
    static func recentRecords(_ kind: RecordKind, sessions: [WorkoutSessionModel], limit: Int = 7) -> [Record] {
        let finished = sessions
            .filter { $0.endedAt != nil && $0.deletedAt == nil && !$0.isRestDay }
            .sorted { ($0.endedAt ?? $0.dateCreated) < ($1.endedAt ?? $1.dateCreated) }
        var best: [String: Record] = [:]
        for session in finished {
            let date = session.endedAt ?? session.dateCreated
            for exercise in session.exercises {
                let sets = exercise.workingSets.filter { $0.completedAt != nil }
                // Strictly greater, so a record matched later keeps the date it was first set.
                guard let value = value(kind, of: sets), value > (best[exercise.templateId]?.value ?? 0) else { continue }
                best[exercise.templateId] = Record(templateId: exercise.templateId, name: exercise.name, value: value, date: date)
            }
        }
        let sorted = best.values.sorted { lhs, rhs in
            lhs.date != rhs.date ? lhs.date > rhs.date : lhs.name.localizedCompare(rhs.name) == .orderedAscending
        }
        return Array(sorted.prefix(limit))
    }

    private static func value(_ kind: RecordKind, of sets: [WorkoutSetModel]) -> Double? {
        switch kind {
        case .volume:
            let volume = sets.compactMap(\.volumeKg).reduce(0, +)
            return volume > 0 ? volume : nil
        case .reps:
            return sets.compactMap(\.reps).max().map(Double.init)
        case .oneRepMax:
            return sets.compactMap { ExerciseOneRMAggregator.estimated1RM(of: $0) }.max()
        }
    }

    // MARK: - Energy balance

    struct EnergyDay: Equatable {
        let date: Date
        /// Calories logged; zero when nothing was.
        let intake: Double
        let expenditure: Double
        /// The diet plan's calories for the day, nil without a plan.
        let target: Double?
    }

    /// Average intake and comparison over the days something was logged. An unlogged day is not
    /// a day of eating nothing, so counting it would invent a deficit.
    static func averages(_ days: [EnergyDay], comparison: (EnergyDay) -> Double?) -> (intake: Double, comparison: Double)? {
        let logged = days.filter { $0.intake > 0 }
        let compared = logged.compactMap(comparison)
        guard !logged.isEmpty, !compared.isEmpty else { return nil }
        return (
            logged.map(\.intake).reduce(0, +) / Double(logged.count),
            compared.reduce(0, +) / Double(compared.count)
        )
    }
}
