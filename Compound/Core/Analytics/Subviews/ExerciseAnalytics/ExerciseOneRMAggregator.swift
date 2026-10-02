//
//  ExerciseOneRMAggregator.swift
//  Compound
//
//  Created by Cursor on 07/02/2026.
//

import Foundation

/// Aggregates estimated 1-RM per exercise (by templateId) from workout sessions.
/// Uses Epley formula: 1RM = weight * (1 + reps/30) for weight+reps sets.
enum ExerciseOneRMAggregator {

    struct Workout1RMPoint {
        let date: Date
        let value: Double
    }

    struct Exercise1RMAggregate {
        var name: String
        var last7Workouts: [Workout1RMPoint]
        var latest1RM: Double
    }

    /// Returns last 7 workouts including the exercise, per templateId.
    /// Each entry is (date: workout date, value: best 1-RM across sets in that workout).
    /// `latest1RM` is the best 1-RM across all workouts.
    static func aggregate(
        sessions: [WorkoutSessionModel]
    ) -> [String: Exercise1RMAggregate] {
        let sorted = sessions.sorted { ($0.endedAt ?? $0.dateCreated) > ($1.endedAt ?? $1.dateCreated) }
        var result: [String: Exercise1RMAggregate] = [:]

        for session in sorted {
            let sessionDate = session.endedAt ?? session.dateCreated

            for exercise in session.exercises {
                let templateId = exercise.templateId
                let name = exercise.name

                let best1RMForWorkout = exercise.sets
                    .filter { !$0.isWarmup && $0.completedAt != nil }
                    .compactMap { set -> Double? in
                        guard let weight = set.weightKg, weight > 0 else { return nil }
                        let reps = set.reps ?? 1
                        return estimated1RM(weightKg: weight, reps: max(1, reps))
                    }
                    .max()

                if let oneRM = best1RMForWorkout, oneRM > 0 {
                    var current = result[templateId] ?? Exercise1RMAggregate(name: name, last7Workouts: [], latest1RM: 0)
                    guard current.last7Workouts.count < 7 else { continue }
                    current.last7Workouts.append(Workout1RMPoint(date: sessionDate, value: oneRM))
                    current.latest1RM = max(current.latest1RM, oneRM)
                    result[templateId] = current
                }
            }
        }

        return result
    }

    /// Epley formula: 1RM = weight * (1 + reps/30). Public for reuse in detail presenters.
    static func estimated1RM(weightKg: Double, reps: Int) -> Double {
        guard reps >= 1 else { return weightKg }
        if reps == 1 { return weightKg }
        return weightKg * (1 + Double(reps) / 30)
    }
}
