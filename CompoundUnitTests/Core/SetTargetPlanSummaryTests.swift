//
//  SetTargetPlanSummaryTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// The line under each planned set in the template editor, and the chip beside its number.
struct SetTargetPlanSummaryTests {

    private let settings = WorkoutSettings(authorId: "user-1")

    @Test("Test A Standard Set Shows Nothing Extra")
    func testStandard() {
        let target = SetTarget(setNumber: 1, minReps: 8, maxReps: 8)

        #expect(SetTargetPlan.summary(for: target, settings: settings) == nil)
        #expect(SetTargetPlan.chip(for: target) == nil)
    }

    @Test("Test A Drop Set To Failure")
    func testDropToFailure() {
        let target = SetTarget(setNumber: 3, minReps: 8, maxReps: 8, setType: .drop, dropCount: 2)

        #expect(SetTargetPlan.summary(for: target, settings: settings) == "8 reps, then −20% ×2 to failure")
        #expect(SetTargetPlan.chip(for: target) == "Drop set")
    }

    @Test("Test A Drop Set With Reps On Each Drop, Its Own Step And A Rep Range")
    func testDropWithReps() {
        let target = SetTarget(setNumber: 1, minReps: 8, maxReps: 12, setType: .drop, dropCount: 1, dropStepPercent: 30, dropReps: 6)

        #expect(SetTargetPlan.summary(for: target, settings: settings) == "8–12 reps, then −30% ×1, 6 reps each")
    }

    @Test("Test A Drop Set With No Reps Planned Starts At The Drops")
    func testDropWithoutReps() {
        let target = SetTarget(setNumber: 1, setType: .drop, dropCount: 2)

        #expect(SetTargetPlan.summary(for: target, settings: settings) == "−20% ×2 to failure")
    }

    @Test("Test An AMRAP Set Names Its Target")
    func testAMRAP() {
        let target = SetTarget(setNumber: 4, setType: .amrap, amrapTargetReps: 8)

        #expect(SetTargetPlan.summary(for: target, settings: settings) == "As many as possible, target 8")
        #expect(SetTargetPlan.chip(for: target) == "AMRAP 8+")
        #expect(SetTargetPlan.summary(for: SetTarget(setNumber: 4, setType: .amrap), settings: settings) == "As many as possible")
    }

    /// Templates saved before AMRAP existed called it a failure set.
    @Test("Test A Legacy Failure Set Reads As AMRAP")
    func testFailureReadsAsAMRAP() {
        let target = SetTarget(setNumber: 1, setType: .failure, amrapTargetReps: 10)

        #expect(SetTargetPlan.title(for: .failure) == "AMRAP")
        #expect(SetTargetPlan.chip(for: target) == "AMRAP 10+")
        #expect(SetTargetPlan.summary(for: target, settings: settings) == "As many as possible, target 10")
    }

    @Test("Test Mini-Sets Read Their Kind's Own Rest")
    func testMiniSets() {
        var settings = settings
        settings.intraSetRestPauseSeconds = 30

        let myo = SetTarget(setNumber: 1, setType: .myo, miniSetCount: 3)
        let pause = SetTarget(setNumber: 1, setType: .restPause, miniSetCount: 1)
        let cluster = SetTarget(setNumber: 1, setType: .cluster, miniSetCount: 4)

        #expect(SetTargetPlan.summary(for: myo, settings: settings) == "3 mini-sets, 15 s breath")
        #expect(SetTargetPlan.summary(for: pause, settings: settings) == "1 mini-set, 30 s breath")
        #expect(SetTargetPlan.summary(for: cluster, settings: settings) == "4 mini-sets, 15 s breath")
    }

    @Test("Test A Kind With No Pieces Planned Reads As Its Reps")
    func testNoPieces() {
        let target = SetTarget(setNumber: 1, minReps: 10, maxReps: 10, setType: .myo)

        #expect(SetTargetPlan.summary(for: target, settings: settings) == "10 reps")
    }

    @Test("Test The Picker Offers Every Kind But The Legacy One")
    func testKinds() {
        #expect(SetTargetPlan.kinds.map(SetTargetPlan.title(for:)) == [
            "Standard", "AMRAP", "Myo-reps", "Rest-pause", "Cluster", "Drop set",
            "Lengthened partials", "Loaded stretch", "Static hold"
        ])
    }

    // MARK: WP-P2

    @Test("Test Partials To Failure Or For A Count")
    func testPartials() {
        let toFailure = SetTarget(setNumber: 3, minReps: 8, maxReps: 8, setType: .partials)
        let five = SetTarget(setNumber: 3, minReps: 8, maxReps: 8, setType: .partials, partialReps: 5)

        #expect(SetTargetPlan.summary(for: toFailure, settings: settings) == "8 reps, then partials to failure")
        #expect(SetTargetPlan.summary(for: five, settings: settings) == "8 reps, then 5 partials")
        #expect(SetTargetPlan.chip(for: toFailure) == "Lengthened partials")
    }

    @Test("Test A Stretch And A Hold Name Their Time")
    func testStretchAndHold() {
        let stretch = SetTarget(setNumber: 3, minReps: 8, maxReps: 12, setType: .stretch, holdSeconds: 30)
        let hold = SetTarget(setNumber: 3, minReps: 8, maxReps: 8, setType: .hold, holdSeconds: 30)

        #expect(SetTargetPlan.summary(for: stretch, settings: settings) == "8–12 reps, then a 30 s stretch")
        #expect(SetTargetPlan.summary(for: hold, settings: settings) == "8 reps, then a 30 s hold")
        #expect(SetTargetPlan.chip(for: stretch) == "Loaded stretch")
        #expect(SetTargetPlan.chip(for: hold) == "Static hold")
        // No time planned reads as the reps alone, as a drop set with no drops does.
        #expect(SetTargetPlan.summary(for: SetTarget(setNumber: 1, minReps: 8, maxReps: 8, setType: .hold), settings: settings) == "8 reps")
        #expect(SetTargetPlan.summary(for: SetTarget(setNumber: 1, setType: .stretch, holdSeconds: 20), settings: settings) == "a 20 s stretch")
    }

    @Test("Test A Drop Can Step By A Quarter")
    func testDropSteps() {
        #expect(SetTargetPlan.dropSteps == [10, 20, 25, 30])
        #expect(SetTargetPlan.holdSecondsChoices == [15, 20, 30, 45, 60])
        #expect(SetTargetPlan.partialRepsRange == 1...10)
    }
}
