//
//  WorkoutSessionPrefillTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// What a session's working sets hold before the user has typed anything.
///
/// The three Initial Log Fill options all land here: the previous session's values (what the app
/// has always done), nothing at all, and smart progression's suggestions. The last one also has
/// to carry the warm-ups with it — a warm-up ramp built for last week's weight is the wrong ramp
/// for a heavier session.
@MainActor
struct WorkoutSessionPrefillTests {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func exerciseModel() -> ExerciseModel {
        ExerciseModel(
            id: "exercise-1",
            authorId: "author-1",
            name: "Bench Press",
            trackableMetrics: [.weight, .reps],
            type: .compoundUpper,
            laterality: .bilateral,
            muscleGroups: [.chest: .primary],
            isBodyweight: false,
            rangeOfMotion: 4,
            stability: 5,
            bodyWeightContribution: 0,
            alternateNames: []
        )
    }

    private func template() -> WorkoutTemplateModel {
        WorkoutTemplateModel(
            id: "template-1",
            authorId: "author-1",
            name: "Push Day",
            exercises: [
                WorkoutTemplateExercise(
                    id: "template-exercise-1",
                    exercise: exerciseModel(),
                    setTargets: (1...3).map { SetTarget(id: "target-\($0)", setNumber: $0, minReps: 8, maxReps: 12) },
                    setRestTimers: false
                )
            ]
        )
    }

    /// A finished session of three sets at 60 kg for ten.
    private func previousSession() -> WorkoutSessionModel {
        let sets = (1...3).map { index in
            WorkoutSetModel(
                id: "previous-set-\(index)",
                authorId: "author-1",
                index: index,
                reps: 10,
                weightKg: 60,
                isWarmup: false,
                completedAt: start,
                dateCreated: start
            )
        }

        return WorkoutSessionModel(
            id: "previous-session",
            authorId: "author-1",
            name: "Push Day",
            workoutTemplateId: "template-1",
            dateCreated: start,
            endedAt: start.addingTimeInterval(3600),
            exercises: [
                WorkoutExerciseModel(
                    id: "previous-exercise",
                    authorId: "author-1",
                    templateId: "exercise-1",
                    name: "Bench Press",
                    trackingMode: .weightReps,
                    index: 1,
                    sets: sets
                )
            ]
        )
    }

    private func workingSets(of session: WorkoutSessionModel) -> [WorkoutSetModel] {
        session.exercises.first?.sets.filter { !$0.isWarmup } ?? []
    }

    private func warmupSets(of session: WorkoutSessionModel) -> [WorkoutSetModel] {
        session.exercises.first?.sets.filter { $0.isWarmup } ?? []
    }

    /// The default, and what every caller got before there was a setting: last session's numbers,
    /// with no progression applied.
    @Test("Test Previous Values Are Carried Over By Default")
    func testPreviousValuesAreCarriedOverByDefault() {
        let session = WorkoutSessionModel(
            authorId: "author-1",
            template: template(),
            previousWorkoutSession: previousSession(),
            dateCreated: start
        )

        #expect(workingSets(of: session).map(\.weightKg) == [60, 60, 60])
        #expect(workingSets(of: session).map(\.reps) == [10, 10, 10])
    }

    /// "Leave empty" means empty even when there is a session to copy from. Somebody who wants to
    /// type every number wants to type every number.
    @Test("Test An Empty Prefill Leaves The Working Sets Blank")
    func testAnEmptyPrefillLeavesTheWorkingSetsBlank() {
        let session = WorkoutSessionModel(
            authorId: "author-1",
            template: template(),
            previousWorkoutSession: previousSession(),
            prefill: .empty,
            dateCreated: start
        )

        let sets = workingSets(of: session)
        #expect(sets.count == 3)
        let allBlank = sets.allSatisfy { $0.weightKg == nil && $0.reps == nil }
        #expect(allBlank)
    }

    /// The suggestion wins over the previous session, and the warm-ups follow it: three sets of
    /// warm-up for a hundred kilos rather than the two the old sixty earned.
    @Test("Test Suggestions Fill The Working Sets And The Warm-Ups Follow")
    func testSuggestionsFillTheWorkingSetsAndTheWarmUpsFollow() {
        let suggestion = ProgressionSuggestion(
            rationale: .progressWeight,
            sets: Array(repeating: SuggestedSet(weightKg: 100, reps: 8), count: 3)
        )

        let session = WorkoutSessionModel(
            authorId: "author-1",
            template: template(),
            previousWorkoutSession: previousSession(),
            prefill: .suggestions(["exercise-1#0": suggestion]),
            dateCreated: start
        )

        #expect(workingSets(of: session).map(\.weightKg) == [100, 100, 100])
        #expect(workingSets(of: session).map(\.reps) == [8, 8, 8])
        #expect(warmupSets(of: session).map(\.weightKg) == [50, 70, 90])
    }

    /// An exercise the engine had nothing to say about falls back to the previous session rather
    /// than starting blank — the user is no worse off than before the feature existed.
    @Test("Test An Exercise With No History Falls Back To The Previous Values")
    func testAnExerciseWithNoHistoryFallsBackToThePreviousValues() {
        let session = WorkoutSessionModel(
            authorId: "author-1",
            template: template(),
            previousWorkoutSession: previousSession(),
            prefill: .suggestions(["exercise-1#0": .noHistory(setCount: 3)]),
            dateCreated: start
        )

        #expect(workingSets(of: session).map(\.weightKg) == [60, 60, 60])
        #expect(workingSets(of: session).map(\.reps) == [10, 10, 10])
    }

    /// A template's drop and failure sets are logged as drop and AMRAP sets; warm-ups stay plain.
    @Test("Test Each Working Set Takes Its Target's Set Type")
    func testEachWorkingSetTakesItsTargetsSetType() {
        var template = template()
        template.exercises[0].setTargets[1].setType = .drop
        template.exercises[0].setTargets[2].setType = .failure

        let session = WorkoutSessionModel(
            authorId: "author-1",
            template: template,
            previousWorkoutSession: previousSession(),
            dateCreated: start
        )

        #expect(workingSets(of: session).map(\.kind) == [.standard, .drop, .amrap])
        #expect(workingSets(of: session).allSatisfy { !$0.isSubSet })
        #expect(warmupSets(of: session).allSatisfy { $0.kind == .standard })
    }

    // MARK: WP-Q

    /// Last time's drop is part of set 1. Matched by position it would hand its 40 kg to set 2.
    @Test("Test Last Time's Drops Are Skipped When Prefilling")
    func testLastTimesDropsAreSkippedWhenPrefilling() {
        var previous = previousSession()
        let drop = WorkoutSetModel(
            id: "previous-drop", authorId: "author-1", index: 4, reps: 12, weightKg: 40,
            kind: .drop, parentSetId: "previous-set-1", isWarmup: false, completedAt: start, dateCreated: start
        )
        previous.exercises[0].sets.insert(drop, at: 1)

        let session = WorkoutSessionModel(
            authorId: "author-1",
            template: template(),
            previousWorkoutSession: previous,
            dateCreated: start
        )

        #expect(workingSets(of: session).map(\.weightKg) == [60, 60, 60])
        #expect(workingSets(of: session).map(\.reps) == [10, 10, 10])
    }

    /// A sub-row among the sets being filled is left alone, the sets around it are filled in
    /// order, and every set keeps its kind and parent.
    @Test("Test Prefill Fills Around A Sub-Set And Keeps Kinds")
    func testPrefillFillsAroundASubSetAndKeepsKinds() {
        var sets = [
            WorkoutSetModel(id: "s1", authorId: "author-1", index: 1, kind: .amrap, isWarmup: false, dateCreated: start),
            WorkoutSetModel(id: "d1", authorId: "author-1", index: 3, kind: .drop, parentSetId: "s1", isWarmup: false, dateCreated: start),
            WorkoutSetModel(id: "s2", authorId: "author-1", index: 2, isWarmup: false, dateCreated: start)
        ]
        let previous = [
            WorkoutSetModel(id: "p1", authorId: "author-1", index: 1, reps: 10, weightKg: 60, isWarmup: false, completedAt: start, dateCreated: start),
            WorkoutSetModel(id: "p2", authorId: "author-1", index: 2, reps: 9, weightKg: 62.5, isWarmup: false, completedAt: start, dateCreated: start)
        ]

        WorkingSetPrefill(
            prefill: .previousValues, previousSets: previous, authorId: "author-1",
            exercise: exerciseModel(), gymProfile: nil, unitPreferences: nil
        ).apply(to: &sets)

        #expect(sets.map(\.weightKg) == [60, nil, 62.5])
        #expect(sets.map(\.reps) == [10, nil, 9])
        #expect(sets.map(\.kind) == [.amrap, .drop, .standard])
        #expect(sets[1].parentSetId == "s1")
    }

    // MARK: - End WP-Q

    // MARK: - WP-S1 set plan

    private func plannedTemplate(_ plan: (inout SetTarget) -> Void) -> WorkoutTemplateModel {
        var template = template()
        plan(&template.exercises[0].setTargets[0])
        return template
    }

    private func session(_ template: WorkoutTemplateModel, plansSets: Bool, previous: WorkoutSessionModel? = nil) -> WorkoutSessionModel {
        WorkoutSessionModel(
            authorId: "author-1",
            template: template,
            previousWorkoutSession: previous ?? previousSession(),
            plansSets: plansSets,
            dateCreated: start
        )
    }

    /// Off, a planned template is created exactly as before: no sub-sets, no AMRAP target.
    @Test("Test With The Set Plan Off A Planned Template Creates No Sub-Sets")
    func testSetPlanOffCreatesNoSubSets() {
        let drop = plannedTemplate { $0.setType = .drop; $0.dropCount = 2 }
        let amrap = plannedTemplate { $0.setType = .amrap; $0.amrapTargetReps = 8 }

        #expect(workingSets(of: session(drop, plansSets: false)).count == 3)
        #expect(workingSets(of: session(amrap, plansSets: false)).allSatisfy { $0.targetReps == nil })
        #expect(workingSets(of: session(amrap, plansSets: false))[0].kind == .amrap)
    }

    /// Each drop is a fifth lighter than the piece before it, to the nearest half kilo.
    @Test("Test A Drop Target Becomes Its Set And Its Drops")
    func testDropTargetExpands() {
        let template = plannedTemplate { $0.setType = .drop; $0.dropCount = 2 }

        let sets = workingSets(of: session(template, plansSets: true))

        #expect(sets.count == 5)
        #expect(sets.map(\.kind) == [.drop, .drop, .drop, .standard, .standard])
        #expect(sets.map(\.weightKg) == [60, 48, 38.5, 60, 60])
        #expect(sets.map(\.reps) == [10, nil, nil, 10, 10])
        #expect(sets[1].parentSetId == sets[0].id && sets[2].parentSetId == sets[0].id)
        #expect(sets.map(\.index) == sets.map(\.index).sorted())
    }

    @Test("Test A Drop's Step And Reps Come From The Plan")
    func testDropStepAndReps() {
        let template = plannedTemplate { $0.setType = .drop; $0.dropCount = 1; $0.dropStepPercent = 30; $0.dropReps = 6 }

        let sets = workingSets(of: session(template, plansSets: true))

        #expect(sets[1].weightKg == 42)
        #expect(sets[1].reps == 6)
    }

    @Test("Test A Mini-Set Target Becomes Its Set And Its Mini-Sets", arguments: [SetTargetSetType.myo, .restPause, .cluster])
    func testMiniSetTargetExpands(setType: SetTargetSetType) {
        let template = plannedTemplate { $0.setType = setType; $0.miniSetCount = 3 }

        let sets = workingSets(of: session(template, plansSets: true))

        #expect(sets.count == 6)
        #expect(sets[0].kind == SetKind(setType))
        #expect(sets[1...3].allSatisfy { $0.kind == .standard && $0.parentSetId == sets[0].id })
        #expect(sets[1...3].allSatisfy { $0.weightKg == 60 && $0.reps == nil })
    }

    @Test("Test An AMRAP Target Carries Its Reps To Beat", arguments: [SetTargetSetType.amrap, .failure])
    func testAMRAPTargetReps(setType: SetTargetSetType) {
        let template = plannedTemplate { $0.setType = setType; $0.amrapTargetReps = 8 }

        let sets = workingSets(of: session(template, plansSets: true))

        #expect(sets[0].kind == .amrap)
        #expect(sets[0].targetReps == 8)
        #expect(sets.count == 3)
    }

    /// Last time's drop is still skipped (WP-Q), and this time's drop steps down from the weight
    /// set 1 was prefilled with, not from last time's drop.
    @Test("Test A Planned Drop Steps Down From The Prefilled Weight, Skipping Last Time's Drops")
    func testPlannedDropAfterPrefillFromSubSets() {
        var previous = previousSession()
        previous.exercises[0].sets.insert(
            WorkoutSetModel(
                id: "previous-drop", authorId: "author-1", index: 4, reps: 12, weightKg: 40,
                kind: .drop, parentSetId: "previous-set-1", isWarmup: false, completedAt: start, dateCreated: start
            ),
            at: 1
        )
        let template = plannedTemplate { $0.setType = .drop; $0.dropCount = 1; $0.dropStepPercent = 25 }

        let sets = workingSets(of: session(template, plansSets: true, previous: previous))

        #expect(sets.map(\.weightKg) == [60, 45, 60, 60])
        #expect(sets.map(\.reps) == [10, nil, 10, 10])
    }

    // MARK: - End WP-S1

    // MARK: - WP-P2 partials, stretch, hold

    @Test("Test A Partials Target Becomes Its Set And One Partials Piece At Its Weight")
    func testPartialsTargetExpands() {
        let toFailure = workingSets(of: session(plannedTemplate { $0.setType = .partials }, plansSets: true))
        let five = workingSets(of: session(plannedTemplate { $0.setType = .partials; $0.partialReps = 5 }, plansSets: true))

        #expect(toFailure.count == 4)
        #expect(toFailure.map(\.kind) == [.partials, .partials, .standard, .standard])
        #expect(toFailure[1].parentSetId == toFailure[0].id)
        #expect(toFailure[1].weightKg == 60)
        #expect(toFailure[1].reps == nil)
        #expect(five[1].reps == 5)
    }

    /// A stretch carries no weight; a hold keeps the set's. Both carry the plan's seconds.
    @Test("Test A Stretch Or Hold Target Becomes Its Set And One Timed Piece")
    func testTimedTargetsExpand() {
        let stretch = workingSets(of: session(plannedTemplate { $0.setType = .stretch; $0.holdSeconds = 30 }, plansSets: true))
        let hold = workingSets(of: session(plannedTemplate { $0.setType = .hold; $0.holdSeconds = 45 }, plansSets: true))

        #expect(stretch.count == 4)
        #expect(stretch[1].kind == .stretch && stretch[1].parentSetId == stretch[0].id)
        #expect(stretch[1].durationSec == 30)
        #expect(stretch[1].weightKg == nil)
        #expect(stretch[1].reps == nil)
        #expect(hold[1].kind == .hold)
        #expect(hold[1].durationSec == 45)
        #expect(hold[1].weightKg == 60)
    }
}
