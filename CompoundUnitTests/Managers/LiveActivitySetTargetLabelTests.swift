//
//  LiveActivitySetTargetLabelTests.swift
//  CompoundUnitTests
//
//  The one label the Live Activity uses for a set (docs/specs/live-activity.md §2, §6).
//

import Testing
import Foundation
@testable import Compound

/// The four tracking shapes, in kg and lb, with nil pieces omitted.
///
/// `Shared/` cannot reach `UnitConversion`, so the formatting is a local copy in the same shape
/// as the tracker's Prev column — these pin the two to the same output.
struct LiveActivitySetTargetLabelTests {

    // MARK: - The four tracking shapes

    @Test("Test Weight And Reps Read As Weight By Reps")
    func testWeightAndRepsReadAsWeightByReps() {
        let target = LiveActivitySetTarget(weightKg: 60, reps: 8)

        #expect(target.label(weightUnit: .kilograms) == "60 kg × 8")
    }

    @Test("Test Reps Only Reads As The Bare Number")
    func testRepsOnlyReadsAsTheBareNumber() {
        #expect(LiveActivitySetTarget(reps: 12).label(weightUnit: .kilograms) == "12")
    }

    @Test("Test Time Only Reads As Minutes And Padded Seconds")
    func testTimeOnlyReadsAsMinutesAndPaddedSeconds() {
        #expect(LiveActivitySetTarget(durationSec: 90).label(weightUnit: .kilograms) == "1:30")
    }

    @Test("Test Distance And Time Read As Distance Then Time")
    func testDistanceAndTimeReadAsDistanceThenTime() {
        let target = LiveActivitySetTarget(durationSec: 600, distanceMeters: 400)

        #expect(target.label(weightUnit: .kilograms) == "400 m 10:00")
    }

    // MARK: - Units

    @Test("Test Weight Converts To Pounds")
    func testWeightConvertsToPounds() {
        let target = LiveActivitySetTarget(weightKg: 60, reps: 8)

        #expect(target.label(weightUnit: .pounds) == "132.3 lb × 8")
        #expect(LiveActivitySetTarget(weightKg: 60).label(weightUnit: .pounds) == "132.3 lb")
    }

    @Test("Test A Fractional Kilogram Keeps One Decimal And A Whole One Drops It")
    func testAFractionalKilogramKeepsOneDecimalAndAWholeOneDropsIt() {
        #expect(LiveActivitySetTarget(weightKg: 62.5).label(weightUnit: .kilograms) == "62.5 kg")
        #expect(LiveActivitySetTarget(weightKg: 60).label(weightUnit: .kilograms) == "60 kg")
    }

    @Test("Test A Distance Over A Kilometre Reads In Kilometres")
    func testADistanceOverAKilometreReadsInKilometres() {
        let target = LiveActivitySetTarget(durationSec: 1_800, distanceMeters: 5_000)

        #expect(target.label(weightUnit: .kilograms) == "5.00 km 30:00")
    }

    // MARK: - Nil pieces

    @Test("Test Nil Pieces Are Omitted")
    func testNilPiecesAreOmitted() {
        #expect(LiveActivitySetTarget(weightKg: 80).label(weightUnit: .kilograms) == "80 kg")
        #expect(LiveActivitySetTarget(distanceMeters: 400).label(weightUnit: .kilograms) == "400 m")
    }

    @Test("Test An Empty Target Has No Label")
    func testAnEmptyTargetHasNoLabel() {
        let target = LiveActivitySetTarget()

        #expect(target.isEmpty)
        #expect(target.label(weightUnit: .kilograms) == nil)
        #expect(target.label(weightUnit: .pounds) == nil)
    }

    // MARK: - Logged set

    @Test("Test A Logged Set Reads The Same Way A Target Does")
    func testALoggedSetReadsTheSameWayATargetDoes() {
        let logged = LoggedSet(setId: "set-1", reps: 8, weightKg: 60)

        #expect(logged.label(weightUnit: .kilograms) == "60 kg × 8")
        #expect(LoggedSet(setId: "set-2").label(weightUnit: .kilograms) == nil)
    }
}
