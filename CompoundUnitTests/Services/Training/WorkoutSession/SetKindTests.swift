//
//  SetKindTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 07/10/2026.
//

import Testing
import Foundation
@testable import Compound

/// Set kinds and sub-sets: every set saved before them still reads, a kind this build does not
/// know reads as standard, and a drop or mini-set is part of its parent rather than a set.
@MainActor
struct SetKindTests {

    private let date = Date(timeIntervalSince1970: 1_000_000)

    private func set(
        _ id: String,
        kind: SetKind = .standard,
        parent: String? = nil,
        side: SetSide? = nil,
        completed: Bool = true
    ) -> WorkoutSetModel {
        WorkoutSetModel(
            id: id, authorId: "author-1", index: 1, reps: 8, weightKg: 100, side: side,
            kind: kind, parentSetId: parent, isWarmup: false, completedAt: completed ? date : nil, dateCreated: date
        )
    }

    private func json(_ set: WorkoutSetModel) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(set)) as? [String: Any])
    }

    private func decode(_ json: [String: Any]) throws -> WorkoutSetModel {
        try JSONDecoder().decode(WorkoutSetModel.self, from: JSONSerialization.data(withJSONObject: json))
    }

    // MARK: - Decoding

    @Test("Test A Set Saved Before Kinds Existed Decodes As A Standard Set Of Its Own")
    func testASetSavedBeforeKindsDecodes() throws {
        var json = try json(set("s1"))
        json.removeValue(forKey: "kind")
        json.removeValue(forKey: "parent_set_id")

        let decoded = try decode(json)

        #expect(decoded.kind == .standard)
        #expect(decoded.parentSetId == nil)
        #expect(!decoded.isSubSet)
    }

    @Test("Test An Unknown Kind Reads As Standard")
    func testAnUnknownKindReadsAsStandard() throws {
        var json = try json(set("s1"))
        json["kind"] = "giantSet"

        #expect(try decode(json).kind == .standard)
    }

    @Test("Test Kind And Parent Round-Trip Under Their Firestore Keys")
    func testKindAndParentRoundTrip() throws {
        for kind in SetKind.allCases {
            let original = set("s2", kind: kind, parent: "s1")
            let json = try json(original)

            #expect(json["kind"] as? String == (kind == .standard ? nil : kind.rawValue))
            #expect(json["parent_set_id"] as? String == "s1")
            let decoded = try decode(json)
            #expect(decoded.kind == kind)
            #expect(decoded.parentSetId == "s1")
            #expect(decoded == original)
        }
    }

    @Test("Test A Template's Set Type Maps To A Kind")
    func testATemplatesSetTypeMapsToAKind() {
        #expect(SetKind(.standard) == .standard)
        #expect(SetKind(.drop) == .drop)
        #expect(SetKind(.myo) == .myo)
        #expect(SetKind(.failure) == .amrap)
        #expect(SetKind(.partials) == .partials)
        #expect(SetKind(.stretch) == .stretch)
        #expect(SetKind(.hold) == .hold)
    }

    // MARK: WP-P2

    @Test("Test Partials, Stretch And Hold Decode From Their Raw Values", arguments: ["partials", "stretch", "hold"])
    func testNewKindsDecode(rawValue: String) throws {
        var json = try json(set("s2", parent: "s1"))
        json["kind"] = rawValue

        #expect(try decode(json).kind.rawValue == rawValue)
        let setType = try JSONDecoder().decode(SetTargetSetType.self, from: JSONEncoder().encode(rawValue))
        #expect(setType.rawValue == rawValue)
    }

    /// The piece follows the set with no breath, so the menu offers no mini-set either.
    @Test("Test Partials, Stretch And Hold Do Not Rest Within The Set", arguments: [SetKind.partials, .stretch, .hold])
    func testNewKindsDoNotRestWithinTheSet(kind: SetKind) {
        #expect(!kind.restsWithinTheSet)
        #expect(WorkoutSettings(authorId: "author-1").intraSetRest(for: kind) == nil)
        #expect(!ActiveWorkout.offersMiniSet(set("s1", kind: kind)))
    }

    /// The set itself is lifted as usual; only the piece after it is timed.
    @Test("Test Only A Stretch Or Hold Piece Is Timed")
    func testOnlyAStretchOrHoldPieceIsTimed() {
        #expect(set("p", kind: .stretch, parent: "s1").isTimedPiece)
        #expect(set("p", kind: .hold, parent: "s1").isTimedPiece)
        #expect(!set("s1", kind: .hold).isTimedPiece)
        #expect(!set("p", kind: .partials, parent: "s1").isTimedPiece)
    }

    /// A timed piece needs a time, not reps, on a weight-and-reps exercise; partials need reps,
    /// as a drop does.
    @Test("Test A Timed Piece Logs With A Time And Partials With Reps")
    func testTimedPieceValidation() {
        var stretch = set("p", kind: .stretch, parent: "s1")
        stretch.reps = nil
        stretch.weightKg = nil
        #expect(SetValidation.problem(with: stretch, trackingMode: .weightReps) == "Enter a time for this set.")
        stretch.durationSec = 30
        #expect(SetValidation.canLog(stretch, trackingMode: .weightReps))

        var partials = set("p", kind: .partials, parent: "s1")
        partials.reps = nil
        #expect(SetValidation.problem(with: partials, trackingMode: .weightReps) == "Enter at least one rep.")
    }

    @Test("Test A Set Target Saved Before Partials And Holds Decodes, And Both Round-Trip")
    func testSetTargetPlanFieldsDecode() throws {
        let target = SetTarget(setNumber: 1, setType: .hold, partialReps: 5, holdSeconds: 30)
        var json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(target)) as? [String: Any])
        #expect(json["partial_reps"] as? Int == 5)
        #expect(json["hold_seconds"] as? Int == 30)
        #expect(try JSONDecoder().decode(SetTarget.self, from: JSONSerialization.data(withJSONObject: json)) == target)

        json.removeValue(forKey: "partial_reps")
        json.removeValue(forKey: "hold_seconds")
        let old = try JSONDecoder().decode(SetTarget.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(old.partialReps == nil)
        #expect(old.holdSeconds == nil)
    }

    // MARK: - Counting

    @Test("Test A Sub-Set Is Not Counted As A Set")
    func testASubSetIsNotCounted() {
        let sets = [set("s1"), set("s1-d1", kind: .drop, parent: "s1"), set("s1-d2", kind: .drop, parent: "s1"), set("s2")]

        #expect(sets.pairedSetCount == 2)
        #expect(sets.fullyCompletedPairedSetCount == 2)
    }

    @Test("Test A Sub-Set Between A Pair Does Not Break The Pair")
    func testASubSetBetweenAPairKeepsThePair() {
        let sets = [set("s1-l", side: .left), set("s1-r", side: .right), set("s1-d", kind: .drop, parent: "s1-l", side: .right), set("s2-l", side: .left)]

        #expect(sets.pairedSetCount == 2)
    }

    @Test("Test A Sub-Set Shares Its Parent's Number")
    func testASubSetSharesItsParentsNumber() {
        let drop = set("s1-d", kind: .drop, parent: "s1")
        let second = set("s2")
        let exercise = WorkoutExerciseModel(
            id: "e1", authorId: "author-1", templateId: "t1", name: "Bench Press",
            trackingMode: .weightReps, index: 1, sets: [set("s1"), drop, second]
        )

        #expect(exercise.workingSetNumber(for: drop) == 1)
        #expect(exercise.workingSetNumber(for: second) == 2)
        #expect(exercise.workingSetCount == 2)
        #expect(exercise.loggedSetCount == 2)
    }

    // MARK: - Progression

    /// Progression reads the parent's figures; a drop's lighter weight is not an attempt.
    @Test("Test Progression History Leaves Sub-Sets Out")
    func testProgressionHistoryLeavesSubSetsOut() {
        let session = WorkoutSessionModel(
            id: "session-1", authorId: "author-1", name: "Push", dateCreated: date, endedAt: date,
            exercises: [
                WorkoutExerciseModel(
                    id: "e1", authorId: "author-1", templateId: "t1", name: "Bench Press",
                    trackingMode: .weightReps, index: 1,
                    sets: [set("s1"), set("s1-d", kind: .drop, parent: "s1"), set("s2")]
                )
            ]
        )

        let history = ProgressionPlanner.history(forTemplateId: "t1", in: [session])

        #expect(history.first?.workingSets.map(\.id) == ["s1", "s2"])
    }

    // MARK: WP-Q

    /// A rest-pause mini-set of one heavy rep would otherwise claim a best 1RM the set never had.
    @Test("Test The 1RM Leaves Sub-Sets Out")
    func testThe1RMLeavesSubSetsOut() {
        var heavySingle = set("s1-m", parent: "s1")
        heavySingle.weightKg = 140
        heavySingle.reps = 1
        let session = WorkoutSessionModel(
            id: "session-1", authorId: "author-1", name: "Push", dateCreated: date, endedAt: date,
            exercises: [
                WorkoutExerciseModel(
                    id: "e1", authorId: "author-1", templateId: "t1", name: "Bench Press",
                    trackingMode: .weightReps, index: 1, sets: [set("s1"), heavySingle]
                )
            ]
        )

        let latest = ExerciseOneRMAggregator.aggregate(sessions: [session])["t1"]?.latest1RM

        #expect(latest == ExerciseOneRMAggregator.estimated1RM(weightKg: 100, reps: 8))
    }

    /// An exercise added part-way through takes its targets' kinds, as one in the template does.
    @Test("Test Default Sets Take Their Targets' Kinds")
    func testDefaultSetsTakeTheirTargetsKinds() {
        let targets = [SetTarget(setNumber: 1, setType: .failure), SetTarget(setNumber: 2, setType: .myo)]

        let sets = WorkoutSessionModel.defaultSets(trackingMode: .weightReps, authorId: "author-1", targetCount: 3, setTargets: targets)

        #expect(sets.map(\.kind) == [.amrap, .myo, .standard])
    }

    // MARK: - End WP-Q
}
