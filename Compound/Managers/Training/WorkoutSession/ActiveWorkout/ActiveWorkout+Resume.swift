//
//  ActiveWorkout+Resume.swift
//  Compound
//
//  What the phone owns up to on return (system.md §2): the sets logged elsewhere since the screen
//  last looked, and how the rest's owner takes a rest back after a cold launch.
//

import Foundation

extension ActiveWorkout {

    // MARK: - Receipt

    /// Sets logged after `lastSeen`, oldest first: the ones logged elsewhere (the Lock Screen,
    /// the Dynamic Island) while the screen was not looking. Nothing when the screen has never
    /// looked, since then there is nothing it could have missed.
    ///
    /// The screen's own logs never land here: every change it makes moves `lastSeen` on.
    static func receipt(in exercises: [WorkoutExerciseModel], loggedAfter lastSeen: Date?) -> [WorkoutSetModel] {
        guard let lastSeen else { return [] }
        return exercises.flatMap(\.sets)
            .filter { ($0.completedAt ?? .distantPast) > lastSeen }
            .sorted { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }
    }

    /// "Set 2 · 100 kg × 8", "Warm-up · 60 kg × 5": one set of the receipt.
    static func receiptLine(
        for set: WorkoutSetModel,
        in exercise: WorkoutExerciseModel,
        unit: ExerciseWeightUnit,
        distanceUnit: ExerciseDistanceUnit
    ) -> String {
        let name = set.isWarmup
            ? String(localized: "Warm-up")
            : String(localized: "Set \("\(exercise.workingSetNumber(for: set))\(set.side?.initial ?? "")")")
        guard let figures = figures(of: set, trackingMode: exercise.trackingMode, unit: unit, distanceUnit: distanceUnit) else {
            return name
        }
        return "\(name) · \(figures)"
    }
}

// MARK: - Restoring a rest

/// What the rest's owner does with the rest it finds in the App Group after a cold launch.
enum RestRestore: Equatable {
    /// Still counting down: re-arm the timer for what is left.
    case running(end: Date, start: Date?)
    /// Ran out while the app was gone: end it once, now.
    case ended(end: Date)
    /// No rest was running.
    case none

    static func plan(restEnd: Date?, restStartedAt: Date?, now: Date) -> RestRestore {
        guard let restEnd else { return .none }
        return restEnd > now ? .running(end: restEnd, start: restStartedAt) : .ended(end: restEnd)
    }
}
