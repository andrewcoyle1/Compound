//
//  ExerciseOneRMAggregator.swift
//  Compound
//
//  Created by Cursor on 07/02/2026.
//

import Foundation

/// Aggregates estimated 1-RM per exercise (by templateId) from workout sessions.
///
/// `estimated1RM` is the app's one estimate of a one-rep max: every screen, record and the AI
/// coach's port (`functions/coach-maths.js`) read it, so they cannot disagree. Epley's form on
/// reps to failure (reps done plus reps in reserve), capped at ten (`MethodInfo.estimatedOneRepMax`).
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
                    // A drop or mini-set is part of its set, and lighter or shorter than it.
                    .filter { !$0.isWarmup && $0.completedAt != nil && !$0.isSubSet }
                    .compactMap { estimated1RM(of: $0) }
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

    /// The most reps to failure an estimate is made from. Prediction equations agree closely at
    /// low reps and drift apart above ten; Reynolds et al. (2006) concluded no more than ten
    /// should be used. A longer set is still logged, and still counts for volume and rep records.
    static let maxRepsToFailure: Double = 10

    /// Reps done plus the reps left in reserve. RIR comes from the logged RPE (RIR = 10 − RPE,
    /// Zourdos et al. 2016); with no RPE the set earns no reserve, rather than being read as an
    /// all-out set or as an easy one.
    static func repsToFailure(reps: Int, rpe: Double?) -> Double {
        let reserve = rpe.map { max(0, EffortScale.rir(fromRPE: $0)) } ?? 0
        return Double(reps) + reserve
    }

    /// Epley's form on reps to failure: weight × (1 + n / 30), and the weight itself at n = 1, so
    /// a single is its own one-rep max rather than 3 % more. `nil` with no weight, or past
    /// `maxRepsToFailure`, where no estimate is trustworthy enough to show.
    static func estimated1RM(weightKg: Double, reps: Int, rpe: Double? = nil) -> Double? {
        guard weightKg > 0, reps >= 1 else { return nil }
        let toFailure = repsToFailure(reps: reps, rpe: rpe)
        guard toFailure <= maxRepsToFailure else { return nil }
        guard toFailure > 1 else { return weightKg }
        return weightKg * (1 + toFailure / 30)
    }

    /// One logged set's estimate. A weight with no reps typed reads as a single, as it always has.
    static func estimated1RM(of set: WorkoutSetModel) -> Double? {
        guard let weight = set.weightKg, weight > 0 else { return nil }
        return estimated1RM(weightKg: weight, reps: max(1, set.reps ?? 1), rpe: set.rpe)
    }

    /// The load to put on the bar for `reps` with `reserve` reps left, from a one-rep max: Epley
    /// turned round. The weight itself at one rep to failure.
    static func load(forOneRepMax oneRepMaxKg: Double, reps: Int, reserve: Double) -> Double {
        let toFailure = Double(max(reps, 1)) + max(reserve, 0)
        guard toFailure > 1 else { return oneRepMaxKg }
        return oneRepMaxKg / (1 + toFailure / 30)
    }
}
