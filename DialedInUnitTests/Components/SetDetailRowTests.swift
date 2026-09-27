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

        #expect(row.weightText == "100.0 kg")
    }

    /// The row printed "%.1f kg" for every set, so a user logging in pounds saw their numbers in kg.
    @Test("Test A Set Logged In Pounds Reads In Pounds")
    func testASetLoggedInPoundsReadsInPounds() {
        let row = SetDetailRow(set: set(weightKg: 100), index: 1, trackingMode: .weightReps, weightUnit: .pounds)

        #expect(row.weightText == "220.5 lbs")
    }

    @Test("Test A Set With No Weight Shows No Weight")
    func testASetWithNoWeightShowsNoWeight() {
        let row = SetDetailRow(set: set(weightKg: nil), index: 1, trackingMode: .weightReps, weightUnit: .pounds)

        #expect(row.weightText == nil)
    }
}
