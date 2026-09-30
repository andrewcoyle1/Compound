//
//  ExerciseModelDetailStats.swift
//  DialedIn
//

import Foundation

/// Everything the History, Charts and Records tabs of the exercise detail screen show, derived
/// from the logged sessions that included this exercise. Those tabs previously read "coming soon"
/// or showed hardcoded figures.
///
/// Built once per load rather than recomputed per section, since all three tabs walk the same
/// sessions.
struct ExerciseModelDetailStats {

    struct Performance: Identifiable {
        var id: String { sessionId }
        let sessionId: String
        let date: Date
        let workoutName: String
        let workingSets: Int
        let totalReps: Int
        let volumeKg: Double
        let bestOneRMKg: Double
        /// The heaviest working set, as weight and the reps achieved at it.
        let heaviestWeightKg: Double
        let repsAtHeaviest: Int
    }

    var performances: [Performance] = []

    var totalSets: Int = 0
    var totalReps: Int = 0
    var totalVolumeKg: Double = 0

    /// The heaviest single working set ever logged, and the session it happened in.
    var heaviestSetKg: Double = 0
    var repsAtHeaviestSet: Int = 0
    var heaviestSetDate: Date?

    var bestOneRMKg: Double = 0

    var isEmpty: Bool { performances.isEmpty }

    /// Most recent first, which is the order the History tab reads in.
    var mostRecentFirst: [Performance] {
        performances.sorted { $0.date > $1.date }
    }

    static func make(from sessions: [WorkoutSessionModel], templateId: String) -> ExerciseModelDetailStats {
        var stats = ExerciseModelDetailStats()

        for session in sessions where session.endedAt != nil {
            let date = session.endedAt ?? session.dateCreated

            for exercise in session.exercises where exercise.templateId == templateId {
                let workingSets = exercise.sets.filter { !$0.isWarmup && $0.completedAt != nil }
                guard !workingSets.isEmpty else { continue }

                let performance = performance(
                    sessionId: session.id,
                    date: date,
                    workoutName: session.name,
                    sets: workingSets
                )
                stats.accumulate(performance)
            }
        }

        return stats
    }

    private static func performance(
        sessionId: String,
        date: Date,
        workoutName: String,
        sets: [WorkoutSetModel]
    ) -> Performance {
        var reps = 0
        var volume: Double = 0
        var bestOneRM: Double = 0
        var heaviest: Double = 0
        var repsAtHeaviest = 0

        for set in sets {
            let setReps = max(1, set.reps ?? 1)
            reps += set.reps ?? 0

            guard let weight = set.weightKg, weight > 0 else { continue }
            volume += weight * Double(setReps)
            bestOneRM = max(bestOneRM, ExerciseOneRMAggregator.estimated1RM(weightKg: weight, reps: setReps))
            // At equal weight the set with more reps is the better one.
            if weight > heaviest || (weight == heaviest && setReps > repsAtHeaviest) {
                heaviest = weight
                repsAtHeaviest = setReps
            }
        }

        return Performance(
            sessionId: sessionId,
            date: date,
            workoutName: workoutName,
            workingSets: sets.count,
            totalReps: reps,
            volumeKg: volume,
            bestOneRMKg: bestOneRM,
            heaviestWeightKg: heaviest,
            repsAtHeaviest: repsAtHeaviest
        )
    }

    private mutating func accumulate(_ performance: Performance) {
        performances.append(performance)
        totalSets += performance.workingSets
        totalReps += performance.totalReps
        totalVolumeKg += performance.volumeKg
        bestOneRMKg = max(bestOneRMKg, performance.bestOneRMKg)

        if performance.heaviestWeightKg > heaviestSetKg
            || (performance.heaviestWeightKg == heaviestSetKg && performance.repsAtHeaviest > repsAtHeaviestSet) {
            heaviestSetKg = performance.heaviestWeightKg
            repsAtHeaviestSet = performance.repsAtHeaviest
            heaviestSetDate = performance.date
        }
    }
}
