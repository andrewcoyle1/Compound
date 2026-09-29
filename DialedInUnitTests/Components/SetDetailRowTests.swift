//
//  SetDetailRowTests.swift
//  DialedInUnitTests
//

import Testing
import Foundation
@testable import DialedIn

/// A finished set's weight, as the session detail lists it.
@MainActor
struct SetDetailRowTests {

    private func set(weightKg: Double?) -> WorkoutSetModel {
        WorkoutSetModel(id: "set-1", authorId: "author-1", index: 1, reps: 8, weightKg: weightKg, isWarmup: false, dateCreated: Date(timeIntervalSince1970: 0))
    }

    @Test("Test A Set Logged In Kilograms Reads In Kilograms")
    func testASetLoggedInKilogramsReadsInKilograms() {
        let row = SetDetailRow(set: set(weightKg: 100), index: 1, trackingMode: .weightReps)

        #expect(row.weightText == "100 kg")
    }

    /// The row printed "%.1f kg" for every set, so a user logging in pounds saw their numbers in kg.
    @Test("Test A Set Logged In Pounds Reads In Pounds")
    func testASetLoggedInPoundsReadsInPounds() {
        let row = SetDetailRow(set: set(weightKg: 100), index: 1, trackingMode: .weightReps, weightUnit: .pounds)

        #expect(row.weightText == "220.5 lb")
    }

    @Test("Test A Set With No Weight Shows No Weight")
    func testASetWithNoWeightShowsNoWeight() {
        let row = SetDetailRow(set: set(weightKg: nil), index: 1, trackingMode: .weightReps, weightUnit: .pounds)

        #expect(row.weightText == nil)
    }

    /// A run logged in miles printed its metres as "5000 m", whatever the exercise was logged in.
    @Test("Test A Distance Reads In The Exercise's Unit")
    func testADistanceReadsInTheExercisesUnit() {
        let run = WorkoutSetModel(
            id: "set-1", authorId: "author-1", index: 1, durationSec: 1530, distanceMeters: 402.336,
            isWarmup: false, dateCreated: Date(timeIntervalSince1970: 0)
        )
        let row = SetDetailRow(set: run, index: 1, trackingMode: .distanceTime, distanceUnit: .miles)

        #expect(row.valueText == "0.25 mi in 25:30")
    }

    @Test("Test Weight And Reps Read As One Line")
    func testWeightAndRepsReadAsOneLine() {
        let row = SetDetailRow(set: set(weightKg: 82.5), index: 1, trackingMode: .weightReps)

        #expect(row.valueText == "82.5 kg × 8 reps")
    }
}
