//
//  RestOverMessage.swift
//  Compound
//
//  What the rest-over alert says, whichever channel carries it: the Live Activity's alert or, for
//  people with Live Activities off, the local notification. Built from the same content state the
//  activity shows, so the alert and the banner beneath it name the same set.
//

import Foundation

#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)

extension WorkoutActivityAttributes.ContentState {

    /// "Next: Bench Press, 60 kg × 8", in the exercise's weight unit. "Next: Bench Press" when the
    /// set holds no figures yet, and nil when nothing is left to do, where the alert's title,
    /// "Rest Complete", says it all.
    var restOverMessage: String? {
        guard !isAllSetsComplete, let name = currentExerciseName, !name.isEmpty else { return nil }
        guard let target = restOverTarget else { return String(localized: "Next: \(name)") }
        return String(localized: "Next: \(name), \(target)")
    }

    /// The target set in the shapes the tracker uses: `60 kg × 8`, `8 reps`, `400 m 1:30`.
    private var restOverTarget: String? {
        let unit: ExerciseWeightUnit = weightUnit == .pounds ? .pounds : .kilograms
        var segments: [String] = []
        switch (targetWeightKg, targetReps) {
        case let (weight?, reps?):
            segments.append("\(Format.weight(kg: weight, unit: unit)) × \(reps.formatted())")
        case let (weight?, nil):
            segments.append(Format.weight(kg: weight, unit: unit))
        case let (nil, reps?):
            segments.append(Format.reps(reps))
        case (nil, nil):
            break
        }
        if let distance = targetDistanceMeters {
            let distanceUnit: ExerciseDistanceUnit = self.distanceUnit == .miles ? .miles : .meters
            segments.append(Format.distance(meters: distance, exerciseUnit: distanceUnit))
        }
        if let duration = targetDurationSec {
            segments.append(Format.duration(TimeInterval(duration)))
        }
        return segments.isEmpty ? nil : segments.joined(separator: " ")
    }
}

#endif
