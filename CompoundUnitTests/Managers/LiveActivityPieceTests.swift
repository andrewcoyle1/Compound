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
}

#endif
