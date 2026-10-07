//
//  AMRAPProgressionTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// An AMRAP set's target under the set plan: up a rep after it is beaten twice running, and at the
/// ceiling the normal weight increment instead, with the target back to the template's.
@MainActor
struct AMRAPProgressionTests {

    private let start = Date(timeIntervalSince1970: 1_000_000)
    private let rule = AMRAPProgression(ceiling: 12)
    private let heavier: (Double) -> Double = { $0 + 2.5 }

    private func amrap(reps: Int?, weightKg: Double? = 100, target: Int? = 8, id: String = "a") -> WorkoutSetModel {
        WorkoutSetModel(
            id: id, authorId: "author-1", index: 1, reps: reps, weightKg: weightKg, kind: .amrap,
            targetReps: target, isWarmup: false, completedAt: start, dateCreated: start
        )
    }

    // MARK: - The rule

    @Test("Test A Target Beaten Twice Running Goes Up A Rep")
    func testBeatenTwiceRaises() {
        let next = rule.next(templateTarget: 8, last: amrap(reps: 10), previous: amrap(reps: 9), heavier: heavier)

        #expect(next == SuggestedSet(weightKg: 100, reps: 9, targetReps: 9))
    }

    @Test("Test A Target Beaten Once, Or Only Met, Holds")
    func testBeatenOnceHolds() {
        #expect(rule.next(templateTarget: 8, last: amrap(reps: 10), previous: amrap(reps: 8), heavier: heavier).targetReps == 8)
        #expect(rule.next(templateTarget: 8, last: amrap(reps: 8), previous: amrap(reps: 11), heavier: heavier).targetReps == 8)
        #expect(rule.next(templateTarget: 8, last: amrap(reps: 10), previous: nil, heavier: heavier).targetReps == 8)
        #expect(rule.next(templateTarget: 8, last: amrap(reps: 10), previous: nil, heavier: heavier).weightKg == 100)
    }

    /// The standing target is last session's, not the template's: a target already raised to 10
    /// has to be beaten at 10.
    @Test("Test The Standing Target Is Last Session's")
    func testStandingTargetIsLastSessions() {
        let held = rule.next(templateTarget: 8, last: amrap(reps: 10, target: 10), previous: amrap(reps: 11, target: 9), heavier: heavier)
        let raised = rule.next(templateTarget: 8, last: amrap(reps: 11, target: 10), previous: amrap(reps: 11, target: 9), heavier: heavier)

        #expect(held.targetReps == 10)
        #expect(raised.targetReps == 11)
    }

    /// A set from before the plan has no target of its own and is judged against the template's.
    @Test("Test A Set Without A Target Is Judged Against The Template's")
    func testNoTargetUsesTemplates() {
        let next = rule.next(templateTarget: 8, last: amrap(reps: 9, target: nil), previous: amrap(reps: 9, target: nil), heavier: heavier)

        #expect(next.targetReps == 9)
    }

    @Test("Test At The Ceiling It Adds Weight And Resets The Target")
    func testCeilingAddsWeight() {
        let next = rule.next(templateTarget: 8, last: amrap(reps: 14, target: 12), previous: amrap(reps: 13, target: 12), heavier: heavier)

        #expect(next == SuggestedSet(weightKg: 102.5, reps: 8, targetReps: 8))
    }

    @Test("Test Bodyweight Work Keeps Raising Past The Ceiling")
    func testBodyweightKeepsRaising() {
        let next = rule.next(templateTarget: 8, last: amrap(reps: 14, weightKg: nil, target: 12), previous: amrap(reps: 13, weightKg: nil, target: 12), heavier: heavier)

        #expect(next.targetReps == 13)
        #expect(next.weightKg == nil)
    }

    // MARK: - In the engine

    private func input(amrap: AMRAPProgression?, setType: SetTargetSetType = .amrap) -> ProgressionInput {
        let targets = [
            SetTarget(id: "t1", setNumber: 1, minReps: 8, maxReps: 12),
            SetTarget(id: "t2", setNumber: 2, minReps: 8, maxReps: 12, setType: setType, amrapTargetReps: 8)
        ]
        let standard = WorkoutSetModel(
            id: "s", authorId: "author-1", index: 1, reps: 9, weightKg: 100, isWarmup: false, completedAt: start, dateCreated: start
        )
        return ProgressionInput(
            trackingMode: .weightReps,
            setTargets: targets,
            history: [
                ProgressionHistorySession(workingSets: [standard, self.amrap(reps: 11)]),
                ProgressionHistorySession(workingSets: [standard, self.amrap(reps: 10)])
            ],
            adjustmentMode: .weightFirst,
            roundWeight: { ($0 * 2).rounded() / 2 },
            minimumIncrementKg: 2.5,
            amrap: amrap
        )
    }

    @Test("Test The Engine Raises A Planned AMRAP Target And Leaves Other Sets To Double Progression", arguments: [SetTargetSetType.amrap, .failure])
    func testEngineRaisesTarget(setType: SetTargetSetType) {
        let suggestion = ProgressionEngine().suggest(input(amrap: rule, setType: setType))

        #expect(suggestion.sets[1] == SuggestedSet(weightKg: 100, reps: 9, targetReps: 9))
        #expect(suggestion.sets[0].targetReps == nil)
        #expect(suggestion.sets[0].weightKg == 100)
    }

    /// With the rule off (set plan off, or Raise Target off) the AMRAP set progresses as today.
    @Test("Test Without The Rule An AMRAP Set Progresses As Before")
    func testWithoutRuleAsBefore() {
        let off = ProgressionEngine().suggest(input(amrap: nil))

        #expect(off.sets.allSatisfy { $0.targetReps == nil })
    }

    @Test("Test The Rule Runs Only With The Set Plan And Raise Target On")
    func testSettingsGateTheRule() {
        var settings = WorkoutSettings(authorId: "author-1")
        #expect(settings.amrapProgression == nil)

        settings.setPlanning = true
        #expect(settings.amrapProgression == AMRAPProgression(ceiling: 12))

        settings.amrapAddsWeightAtTarget = 15
        #expect(settings.amrapProgression?.ceiling == 15)

        settings.amrapRaisesTarget = false
        #expect(settings.amrapProgression == nil)
    }

    // MARK: - Into the next session

    /// The raised target reaches the new session, and every set keeps its kind and its parent.
    @Test("Test A Raised Target Reaches The Next Session With Kinds And Parents Kept")
    func testRaisedTargetReachesSession() {
        let exercise = ExerciseModel(
            id: "exercise-1", authorId: "author-1", name: "Bench Press", trackableMetrics: [.weight, .reps],
            type: .compoundUpper, laterality: .bilateral, muscleGroups: [.chest: .primary], isBodyweight: false,
            rangeOfMotion: 4, stability: 5, bodyWeightContribution: 0, alternateNames: []
        )
        let template = WorkoutTemplateModel(
            id: "template-1", authorId: "author-1", name: "Push Day",
            exercises: [
                WorkoutTemplateExercise(
                    id: "te-1", exercise: exercise,
                    setTargets: [
                        SetTarget(setNumber: 1, setType: .drop, dropCount: 1),
                        SetTarget(setNumber: 2, setType: .amrap, amrapTargetReps: 8)
                    ],
                    setRestTimers: false
                )
            ]
        )
        let suggestion = ProgressionSuggestion(
            rationale: .hold,
            sets: [SuggestedSet(weightKg: 100, reps: 10), SuggestedSet(weightKg: 80, reps: 9, targetReps: 9)]
        )

        let session = WorkoutSessionModel(
            authorId: "author-1", template: template, prefill: .suggestions(["exercise-1": suggestion]),
            plansSets: true, dateCreated: start
        )
        let sets = session.exercises[0].sets.filter { !$0.isWarmup }

        #expect(sets.map(\.kind) == [.drop, .drop, .amrap])
        #expect(sets[1].parentSetId == sets[0].id)
        #expect(sets.map(\.weightKg) == [100, 80, 80])
        #expect(sets[2].targetReps == 9)
    }
}
