//
//  SetBandsDisplayTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// How a set's resistance bands read wherever its weight is shown (`Format.load`).
@MainActor
struct SetBandsDisplayTests {

    private func set(weightKg: Double?) -> WorkoutSetModel {
        WorkoutSetModel(id: UUID().uuidString, authorId: "u", index: 1, reps: 8, weightKg: weightKg, isWarmup: false, dateCreated: .now)
    }

    /// One helper joins a set's weight and bands for the set row, the previous column, the log
    /// button and the session detail screen.
    @Test("Test A Set's Bands Read With Its Weight")
    func testBandsReadWithTheWeight() {
        let kg60 = Format.weight(kg: 60, unit: .kilograms)
        #expect(Format.load(nil, bands: nil) == nil)
        #expect(Format.load(nil, bands: []) == nil)
        #expect(Format.load(kg60, bands: nil) == kg60)
        #expect(Format.load(nil, bands: ["Red", "Blue"]) == "Red + Blue")
        #expect(Format.load(kg60, bands: ["Red"]) == "\(kg60) + Red")

        var bandsOnly = set(weightKg: nil)
        bandsOnly.bands = ["Red", "Blue"]
        var both = set(weightKg: 60)
        both.bands = ["Red"]
        let plain = set(weightKg: 60)
        #expect(ActiveWorkout.figures(of: bandsOnly, trackingMode: .weightReps, unit: .kilograms, distanceUnit: .meters) == "Red + Blue × 8")
        #expect(ActiveWorkout.figures(of: both, trackingMode: .weightReps, unit: .kilograms, distanceUnit: .meters) == "\(kg60) + Red × 8")
        #expect(ActiveWorkout.figures(of: plain, trackingMode: .weightReps, unit: .kilograms, distanceUnit: .meters) == "\(kg60) × 8")

        // The session detail screen's row.
        #expect(SetDetailRow(set: bandsOnly, index: 1, trackingMode: .weightReps).valueText == "Red + Blue × \(Format.reps(8))")
        #expect(SetDetailRow(set: both, index: 2, trackingMode: .weightReps).valueText == "\(kg60) + Red × \(Format.reps(8))")
    }
}
