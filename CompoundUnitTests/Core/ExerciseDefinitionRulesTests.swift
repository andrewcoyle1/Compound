//
//  ExerciseDefinitionRulesTests.swift
//  CompoundUnitTests
//

import Testing
@testable import Compound

/// `isBodyweight` means "cannot be loaded"; the contribution belongs to the movement and is checked
/// on its own.
struct ExerciseDefinitionRulesTests {

    @Test("Test The Contribution Is A Percentage", arguments: [(-1, false), (0, true), (75, true), (100, true), (101, false)])
    func testTheContributionIsAPercentage(value: Int, valid: Bool) {
        #expect(ExerciseDefinitionRules.isValid(contribution: value) == valid)
    }

    @Test("Test A Bodyweight Exercise Cannot Track A Load", arguments: [
        TrackableExerciseMetric.weight, .weightPerSide, .weightPerSidePersistent
    ])
    func testABodyweightExerciseCannotTrackALoad(metric: TrackableExerciseMetric) {
        #expect(ExerciseDefinitionRules.bodyweightConflict(isBodyweight: true, metrics: [.reps, metric]))
        #expect(!ExerciseDefinitionRules.bodyweightConflict(isBodyweight: false, metrics: [.reps, metric]))
    }

    /// An assisted machine is bodyweight minus the assistance, so it stays a bodyweight exercise.
    @Test("Test Assistance And Unloaded Metrics Are Allowed")
    func testAssistanceAndUnloadedMetricsAreAllowed() {
        #expect(!ExerciseDefinitionRules.bodyweightConflict(isBodyweight: true, metrics: [.repsPerSide, .weightPerSideAssistance]))
        #expect(!ExerciseDefinitionRules.bodyweightConflict(isBodyweight: true, metrics: [.reps]))
        #expect(!ExerciseDefinitionRules.bodyweightConflict(isBodyweight: true, metrics: [.duration, .distanceShort]))
    }
}
