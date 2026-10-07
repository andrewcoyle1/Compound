//
//  LiveActivityPieceTests.swift
//  CompoundUnitTests
//
//  The Live Activity with Workout Settings › Set Plan on: which piece of a drop or mini-set set
//  the target is, what the banner calls it, how the progress line splits, when a rest is the
//  breath inside a set, and that Complete walks the pieces through the one log rule.
//

import Testing
import Foundation
@testable import Compound

#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)

@MainActor
struct LiveActivityPieceTests {

    private static let start = Date(timeIntervalSince1970: 1_772_000_000)

    // MARK: - Fixtures

    private func row(
        _ id: String,
        index: Int,
        kind: SetKind = .standard,
        parent: String? = nil,
        weightKg: Double = 100,
        side: SetSide? = nil,
        done: Bool = false
    ) -> WorkoutSetModel {
        WorkoutSetModel(
            id: id, authorId: "author-1", index: index, reps: 8, weightKg: weightKg, side: side,
            kind: kind, parentSetId: parent, isWarmup: false,
            completedAt: done ? Self.start : nil, dateCreated: Self.start
        )
    }

    /// Set 1 plain, set 2 a drop set with two drops, set 3 myo-reps with two mini-sets.
    private func sets(done: Set<String> = []) -> [WorkoutSetModel] {
        [
            row("s1", index: 1),
            row("s2", index: 2, kind: .drop),
            row("s2-d1", index: 3, kind: .drop, parent: "s2", weightKg: 80),
            row("s2-d2", index: 4, kind: .drop, parent: "s2", weightKg: 64),
            row("s3", index: 5, kind: .myo),
            row("s3-m1", index: 6, parent: "s3"),
            row("s3-m2", index: 7, parent: "s3")
        ].map { set in
            var set = set
            if done.contains(set.id) { set.completedAt = Self.start }
            return set
        }
    }

    private func session(_ sets: [WorkoutSetModel]) -> WorkoutSessionModel {
        WorkoutSessionModel(
            id: "session-1", authorId: "author-1", name: "Push Day", dateCreated: Self.start,
            exercises: [WorkoutExerciseModel(
                id: "e1", authorId: "author-1", templateId: "template-1", name: "Bench Press",
                trackingMode: .weightReps, index: 1, sets: sets
            )]
        )
    }

    private func state(
        _ session: WorkoutSessionModel,
        plansSets: Bool = true,
        restEndsAt: Date? = nil
    ) -> WorkoutActivityAttributes.ContentState {
        LiveActivityManager(logger: LogManager(), activityLookup: { _ in nil }, plansSets: { plansSets })
            .makeContentState(session: session, isActive: true, currentExerciseIndex: 0, restEndsAt: restEndsAt)
    }

    // MARK: - Which piece

    @Test("A drop set's own row is piece 1 and names no piece")
    func dropSetParentIsPieceOne() throws {
        let sets = sets()
        let piece = try #require(LiveActivityManager.piece(of: sets[1], in: sets))

        #expect(piece == SetPiece(index: 1, count: 3, isDrop: true))
        #expect(piece.label == nil)
        #expect(!piece.restIsWithinTheSet)
    }

    @Test("A drop reads as its place among the drops")
    func dropReadsAsDropOneOfTwo() throws {
        let sets = sets()
        let piece = try #require(LiveActivityManager.piece(of: sets[2], in: sets))

        #expect(piece.label == "Drop 1 of 2")
        #expect(piece.restIsWithinTheSet)
    }

    @Test("A mini-set reads as a mini-set")
    func miniSetReadsAsMiniSet() throws {
        let sets = sets()
        #expect(LiveActivityManager.piece(of: sets[6], in: sets)?.label == "Mini-set 2 of 2")
    }

    @Test("A plain set has no piece and no kind")
    func plainSetHasNoPiece() {
        let sets = sets()
        #expect(LiveActivityManager.piece(of: sets[0], in: sets) == nil)
        #expect(LiveActivityManager.kind(of: sets[0], in: sets) == nil)
    }

    @Test("A piece takes its set's kind: a mini-set stored plain is still myo-reps")
    func pieceTakesItsSetsKind() {
        let sets = sets()
        #expect(LiveActivityManager.kind(of: sets[2], in: sets) == .drop)
        #expect(LiveActivityManager.kind(of: sets[5], in: sets) == .myo)
        #expect(LiveActivityManager.kind(of: row("a", index: 1, kind: .amrap), in: []) == .amrap)
    }

    // MARK: - Labels

    @Test("The banner names the set and the piece")
    func positionLabelNamesSetAndPiece() {
        let drop = SetPiece(index: 2, count: 3, isDrop: true)
        #expect(SetPosition(index: 3, total: 4, piece: drop).label == "Set 3 · Drop 1 of 2")
        #expect(SetPosition(index: 1, total: 4, side: "L", piece: drop).label == "Set 1L · Drop 1 of 2")
        #expect(SetPosition(index: 3, total: 4, piece: SetPiece(index: 1, count: 3, isDrop: true)).label == "Set 3 of 4")
    }

    // MARK: - Counting and progress

    @Test("A set counts as done once its last piece is")
    func setCountsDoneAtItsLastPiece() {
        let partway = LiveActivityManager.countingPieces(sets(done: ["s1", "s2", "s2-d1"]))
        #expect(partway.fullyCompletedPairedSetCount == 1)

        let finished = LiveActivityManager.countingPieces(sets(done: ["s1", "s2", "s2-d1", "s2-d2"]))
        #expect(finished.fullyCompletedPairedSetCount == 2)
    }

    @Test("The set under way splits its share of the progress line into its pieces")
    func progressSplitsIntoPieces() {
        let piece = SetPiece(index: 2, count: 4, isDrop: false)

        let progress: Double = 1.25 / 4
        let dividers: [Double] = [1.25 / 4, 1.5 / 4, 1.75 / 4]
        #expect(piece.progress(completedSets: 1, totalSets: 4) == progress)
        #expect(piece.dividers(completedSets: 1, totalSets: 4) == dividers)
        #expect(SetPiece(index: 1, count: 1, isDrop: false).dividers(completedSets: 0, totalSets: 4).isEmpty)
        #expect(piece.progress(completedSets: 0, totalSets: 0) == 0)
    }

    // MARK: - The content state

    @Test("With the plan on, drop 1 still reads set 2 and carries its piece and kind")
    func contentStateOnDropOne() {
        let state = state(session(sets(done: ["s1", "s2"])))

        #expect(state.targetSetId == "s2-d1")
        #expect(state.currentExerciseCompletedSetsCount == 1)
        #expect(state.targetKind == .drop)
        #expect(state.targetPiece == SetPiece(index: 2, count: 3, isDrop: true))
        let progress: Double = (1 + 1.0 / 3) / 3
        #expect(state.progress == progress)
        #expect(LiveActivityPhase.position(state).label == "Set 2 · Drop 1 of 2")
    }

    @Test("With the plan off, the state is as it always was")
    func contentStateWithThePlanOff() {
        let state = state(session(sets(done: ["s1", "s2"])), plansSets: false)

        #expect(state.targetSetId == "s2-d1")
        #expect(state.currentExerciseCompletedSetsCount == 2)
        #expect(state.targetKind == nil)
        #expect(state.targetPiece == nil)
        let progress: Double = 2.0 / 3
        #expect(state.progress == progress)
    }

    // MARK: - Which rest

    @Test("A rest before a mini-set is the breath, drawn as a bar")
    func restBeforeMiniSetIsTheBreath() throws {
        let now = Date()
        let state = state(session(sets(done: ["s1", "s2", "s2-d1", "s2-d2", "s3"])), restEndsAt: now.addingTimeInterval(15))

        guard case let .breathing(_, next, position) = LiveActivityPhase(state: state, now: now, isStale: false) else {
            Issue.record("expected the breath")
            return
        }
        #expect(next == LiveActivitySetTarget(weightKg: 100, reps: 8))
        #expect(position.label == "Set 3 · Mini-set 1 of 2")
    }

    @Test("A rest before a set's first piece is the rest between sets")
    func restBeforeASetIsTheRestBetweenSets() {
        let now = Date()
        let state = state(session(sets(done: ["s1"])), restEndsAt: now.addingTimeInterval(90))

        guard case .resting = LiveActivityPhase(state: state, now: now, isStale: false) else {
            Issue.record("expected the rest between sets")
            return
        }
    }

    // MARK: - Complete walks the pieces

    /// Each tap logs the target through `ActiveWorkout.log`, as the Lock Screen's Complete does,
    /// and the next state's target is the next piece, with the rest the rule gives: none before a
    /// drop, the myo breath before a mini-set, a full rest between sets.
    @Test("Complete walks the drops and mini-sets in order")
    func completeWalksThePieces() throws {
        var settings = WorkoutSettings(authorId: "author-1")
        settings.defaultRestDurationSeconds = 90
        let context = RestDurationRules.ExerciseContext(restOverrideSeconds: nil, exerciseTypeRawValue: nil)
        var session = session(sets())
        var targets: [String] = []
        var labels: [String] = []
        var rests: [Int?] = []

        while let target = state(session).targetSetId {
            let label = LiveActivityPhase.position(state(session)).label
            let outcome = try #require(ActiveWorkout.log(setId: target, in: session, settings: settings, context: context))
            #expect(outcome.problem == nil)
            targets.append(target)
            labels.append(label)
            rests.append(outcome.restSeconds)
            session = outcome.session
        }

        #expect(targets == ["s1", "s2", "s2-d1", "s2-d2", "s3", "s3-m1", "s3-m2"])
        #expect(labels == [
            "Set 1 of 3", "Set 2 of 3", "Set 2 · Drop 1 of 2", "Set 2 · Drop 2 of 2",
            "Set 3 of 3", "Set 3 · Mini-set 1 of 2", "Set 3 · Mini-set 2 of 2"
        ])
        #expect(rests == [90, nil, nil, 90, 15, 15, nil])
    }
}

#endif
