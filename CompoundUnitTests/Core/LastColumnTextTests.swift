//
//  LastColumnTextTests.swift
//  CompoundUnitTests
//
//  The row's Last column: last session's set, as each tracking mode shows it.
//

import Foundation
import Testing
@testable import Compound

@MainActor
struct LastColumnTextTests {

    private func set(reps: Int? = nil, weightKg: Double? = nil, durationSec: Int? = nil, distanceMeters: Double? = nil) -> WorkoutSetModel {
        WorkoutSetModel(
            id: "s1", authorId: "a", index: 1, reps: reps, weightKg: weightKg, durationSec: durationSec,
            distanceMeters: distanceMeters, isWarmup: false, dateCreated: Date(timeIntervalSince1970: 0)
        )
    }

    private func text(_ set: WorkoutSetModel, _ mode: TrackingMode, showsBodyweight: Bool = false) -> String? {
        ActiveWorkout.lastColumnText(of: set, trackingMode: mode, unit: .kilograms, distanceUnit: .meters, showsBodyweight: showsBodyweight)
    }

    @Test func eachModeReadsAsTheColumnShowsIt() {
        #expect(text(set(reps: 8, weightKg: 100), .weightReps) == ActiveWorkout.figures(of: set(reps: 8, weightKg: 100), trackingMode: .weightReps, unit: .kilograms, distanceUnit: .meters))
        // Reps alone read as a number in the narrow column, not "8 reps".
        #expect(text(set(reps: 8), .repsOnly) == "8")
        #expect(text(set(durationSec: 90), .timeOnly) == Format.duration(90))
        // A distance and its time with a space, so they wrap onto two lines.
        #expect(text(set(durationSec: 90, distanceMeters: 400), .distanceTime) == "\(Format.distance(meters: 400, exerciseUnit: .meters)) \(Format.duration(90))")
    }

    @Test func aSetMissingItsFiguresReadsNothing() {
        #expect(text(set(weightKg: 100), .weightReps) == nil)
        #expect(text(set(), .repsOnly) == nil)
        #expect(text(set(), .timeOnly) == nil)
        #expect(text(set(distanceMeters: 400), .distanceTime) == nil)
    }
}
