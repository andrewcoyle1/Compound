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
        #expect(SetTargetPlan.kinds.map(SetTargetPlan.title(for:)) == ["Standard", "AMRAP", "Myo-reps", "Rest-pause", "Cluster", "Drop set"])
    }
}
