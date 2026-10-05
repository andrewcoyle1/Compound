//
//  WorkoutSetSideTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
@testable import Compound

/// Sets worked one limb at a time.
///
/// A single-arm row starts as one `both` row per set, and splits into a left and a right row when
/// the arms differ — but either way the user did one set, and a screen that says otherwise is telling them they have
/// done twice the work they have. Everything here defends that one rule: sides are told apart by
/// `side`, never by position or index; a left and a right count as one set everywhere a set count
/// is shown; and volume is the deliberate exception, because both arms really did lift.
@MainActor
struct WorkoutSetSideTests {

    private let date = Date(timeIntervalSince1970: 1_000_000)

    private func set(
        index: Int,
        side: SetSide? = nil,
        reps: Int? = 10,
        weightKg: Double? = 20,
        isWarmup: Bool = false,
        completed: Bool = false
    ) -> WorkoutSetModel {
        WorkoutSetModel(
            id: "set-\(index)",
            authorId: "author-1",
            index: index,
            reps: reps,
            weightKg: weightKg,
            side: side,
            isWarmup: isWarmup,
            completedAt: completed ? date : nil,
            dateCreated: date
        )
    }

    private func exercise(sets: [WorkoutSetModel], targets: [SetTarget] = []) -> WorkoutExerciseModel {
        WorkoutExerciseModel(
            id: "exercise-1",
            authorId: "author-1",
            templateId: "system-single-arm-row",
            name: "Single Arm Row",
            trackingMode: .weightReps,
            index: 1,
            sets: sets,
            setTargets: targets
        )
    }

    /// Three sets a side: six rows, numbered 1 to 6, left then right.
    private var threeSetsPerSide: [WorkoutSetModel] {
        [
            set(index: 1, side: .left), set(index: 2, side: .right),
            set(index: 3, side: .left), set(index: 4, side: .right),
            set(index: 5, side: .left), set(index: 6, side: .right)
        ]
    }

    private func exerciseModel(metrics: [TrackableExerciseMetric], laterality: Laterality? = nil) -> ExerciseModel {
        ExerciseModel(
            id: "exercise-model-1",
            authorId: "author-1",
            name: "Single Arm Row",
            trackableMetrics: metrics,
            type: .compoundUpper,
            laterality: laterality,
            muscleGroups: [:],
            isBodyweight: false,
            rangeOfMotion: 1,
            stability: 1,
            bodyWeightContribution: 0,
            alternateNames: []
        )
    }

    // MARK: - Which exercises are worked a side at a time

    /// The three metrics that genuinely mean one limb at a time.
    @Test("Test A Per-Side Metric Makes An Exercise Two-Sided")
    func testAPerSideMetricMakesAnExerciseTwoSided() {
        #expect(WorkoutSessionModel.isPerSide(exerciseModel(metrics: [.repsPerSide, .weight])))
        #expect(WorkoutSessionModel.isPerSide(exerciseModel(metrics: [.durationPerSide])))
        #expect(WorkoutSessionModel.isPerSide(exerciseModel(metrics: [.distanceShortPerSide])))
    }

    /// "Weight per side" is the plates on each end of a barbell as often as it is one hand, and
    /// the persistent one is explicitly a single weight used on both sides. None of them splits a
    /// set in two, and treating them as if they did would double every barbell lift in the app.
    @Test("Test The Weight Per-Side Metrics Do Not Split A Set")
    func testTheWeightPerSideMetricsDoNotSplitASet() {
        #expect(!WorkoutSessionModel.isPerSide(exerciseModel(metrics: [.weightPerSide, .reps])))
        #expect(!WorkoutSessionModel.isPerSide(exerciseModel(metrics: [.weightPerSidePersistent, .reps])))
        #expect(!WorkoutSessionModel.isPerSide(exerciseModel(metrics: [.weightPerSideAssistance, .reps])))
        #expect(!WorkoutSessionModel.isPerSide(exerciseModel(metrics: [.weight, .reps])))
    }

    /// `laterality` looks like the obvious answer and is not: it is optional and nearly every
    /// exercise leaves it empty, so reading it would classify a single-arm row as two-sided only
    /// on the handful of seeded exercises that happen to fill it in.
    @Test("Test Laterality Is Not What Decides")
    func testLateralityIsNotWhatDecides() {
        #expect(WorkoutSessionModel.isPerSide(exerciseModel(metrics: [.repsPerSide], laterality: nil)))
        #expect(!WorkoutSessionModel.isPerSide(exerciseModel(metrics: [.reps], laterality: .unilateral)))
    }

    // MARK: - Generating sets in pairs

    /// Asking for three sets of a per-side exercise means three rows logged for both sides: the
    /// user nearly always matches the arms, and a row per arm was a second tick for nothing.
    @Test("Test Three Sets A Side Are Minted As Three Rows For Both Sides")
    func testThreeSetsASideAreMintedAsThreeRowsForBothSides() {
        let sets = WorkoutSessionModel.defaultSets(
            trackingMode: .weightReps,
            authorId: "author-1",
            targetCount: 3,
            perSide: true
        )

        #expect(sets.map(\.side) == [.both, .both, .both])
        #expect(sets.map(\.index) == [1, 2, 3])
        #expect(sets.pairedSetCount == 3)
    }

    /// A two-sided exercise is untouched: three sets, three rows, no side at all.
    @Test("Test A Two-Sided Exercise Mints Plain Sets")
    func testATwoSidedExerciseMintsPlainSets() {
        let sets = WorkoutSessionModel.defaultSets(trackingMode: .weightReps, authorId: "author-1", targetCount: 3)

        #expect(sets.count == 3)
        #expect(sets.allSatisfy { $0.side == nil })
        #expect(sets.pairedSetCount == 3)
    }

    /// The starting figures each tracking mode fills in are unchanged by the split — both limbs of
    /// a timed hold still start at a minute.
    @Test("Test Each Tracking Mode Keeps Its Starting Figures")
    func testEachTrackingModeKeepsItsStartingFigures() {
        let timed = WorkoutSessionModel.defaultSets(
            trackingMode: .timeOnly, authorId: "author-1", targetCount: 2, perSide: true
        )
        let run = WorkoutSessionModel.defaultSets(trackingMode: .distanceTime, authorId: "author-1", targetCount: 1)

        #expect(timed.count == 2)
        #expect(timed.allSatisfy { $0.durationSec == 60 && $0.distanceMeters == nil })
        #expect(run.first?.durationSec == 120)
        #expect(run.first?.distanceMeters == 400)
    }

    // MARK: - Counting

    /// The number the user is shown. Three sets a side is three sets, not six.
    @Test("Test A Per-Side Exercise Reports Three Sets Not Six")
    func testAPerSideExerciseReportsThreeSetsNotSix() {
        let exercise = exercise(sets: threeSetsPerSide)

        #expect(exercise.sets.count == 6)
        #expect(exercise.workingSetCount == 3)
    }

    /// Volume is the exception and needs both rows: three sets of ten reps a side at twenty kilos
    /// really is 6 × 10 × 20 of work lifted, and halving it would show the user losing strength
    /// they never lost.
    @Test("Test Volume Still Counts Both Sides")
    func testVolumeStillCountsBothSides() {
        let exercise = exercise(sets: threeSetsPerSide)

        let volume = exercise.workingSets.compactMap(\.volumeKg).reduce(0, +)

        #expect(volume == 1200)
    }

    /// A row logged for both sides is both arms' work, so it counts as the pair it stands for —
    /// otherwise not splitting would halve the user's volume.
    @Test("Test A Row For Both Sides Counts Twice In Volume")
    func testARowForBothSidesCountsTwiceInVolume() {
        #expect(set(index: 1, side: .both, reps: 10, weightKg: 20).volumeKg == 400)
        #expect(set(index: 1, side: .left, reps: 10, weightKg: 20).volumeKg == 200)
        #expect(set(index: 1, reps: 10, weightKg: 20).volumeKg == 200)
        #expect(set(index: 1, side: .both, reps: nil).volumeKg == nil)
    }

    // MARK: - Splitting and joining

    /// Splitting copies each row to both arms, tick included, and keeps the left on the row's id.
    @Test("Test Splitting Turns Each Row Into A Pair")
    func testSplittingTurnsEachRowIntoAPair() {
        let sets = [
            set(index: 1, isWarmup: true),
            set(index: 2, side: .both, reps: 8, completed: true),
            set(index: 3, side: .both, reps: 6)
        ].splittingSides()

        #expect(sets.map(\.side) == [nil, .left, .right, .left, .right])
        #expect(sets.map(\.index) == [1, 2, 3, 4, 5])
        #expect(sets.map(\.reps) == [10, 8, 8, 6, 6])
        #expect(sets.map { $0.completedAt != nil } == [false, true, true, false, false])
        #expect(sets[1].id == "set-2")
        #expect(Set(sets.map(\.id)).count == 5)
        #expect(exercise(sets: sets).workingSetCount == 2)
    }

    /// Joining keeps the left arm's figures, and a pair with one arm still to do is not done.
    @Test("Test Joining Turns Each Pair Into One Row")
    func testJoiningTurnsEachPairIntoOneRow() {
        let sets = [
            set(index: 1, side: .left, weightKg: 20, completed: true),
            set(index: 2, side: .right, weightKg: 22.5),
            set(index: 3, side: .left, weightKg: 25, completed: true),
            set(index: 4, side: .right, weightKg: 27.5, completed: true)
        ].joiningSides()

        #expect(sets.map(\.id) == ["set-1", "set-3"])
        #expect(sets.map(\.side) == [.both, .both])
        #expect(sets.map(\.index) == [1, 2])
        #expect(sets.map(\.weightKg) == [20, 25])
        #expect(sets.map { $0.completedAt != nil } == [false, true])
    }

    @Test("Test Split And Sides Per Set Follow The Rows")
    func testSplitAndSidesPerSetFollowTheRows() {
        let both = exercise(sets: [set(index: 1, side: .both)])
        let split = exercise(sets: threeSetsPerSide)
        let plain = exercise(sets: [set(index: 1)])

        #expect(both.isPerSide && !both.isSplit && both.sidesPerSet == [.both])
        #expect(split.isPerSide && split.isSplit && split.sidesPerSet == [.left, .right])
        #expect(!plain.isPerSide && !plain.isSplit && plain.sidesPerSet == [nil])
    }

    /// A pair counts from the moment either limb is done — the left arm being behind them is
    /// progress, and the fraction on screen has to move when the user taps the tick.
    @Test("Test A Half-Finished Pair Counts As One Set Done")
    func testAHalfFinishedPairCountsAsOneSetDone() {
        var sets = threeSetsPerSide
        sets[0] = set(index: 1, side: .left, completed: true)

        #expect(exercise(sets: sets).loggedSetCount == 1)
    }

    @Test("Test A Finished Pair Counts As One Set Done")
    func testAFinishedPairCountsAsOneSetDone() {
        var sets = threeSetsPerSide
        sets[0] = set(index: 1, side: .left, completed: true)
        sets[1] = set(index: 2, side: .right, completed: true)

        #expect(exercise(sets: sets).loggedSetCount == 1)
    }

    /// Warm-ups stay single-sided — a ramp is not a per-limb effort — and still do not count as
    /// work done.
    @Test("Test Warm-Ups Are Not Paired Or Counted")
    func testWarmUpsAreNotPairedOrCounted() {
        let exercise = exercise(sets: [
            set(index: 1, isWarmup: true, completed: true),
            set(index: 2, isWarmup: true, completed: true),
            set(index: 3, side: .left, completed: true),
            set(index: 4, side: .right, completed: true)
        ])

        #expect(exercise.loggedSetCount == 1)
        #expect(exercise.workingSetCount == 1)
    }

    /// Nothing changes for an exercise without sides, which is nearly all of them.
    @Test("Test Plain Sets Count One Each")
    func testPlainSetsCountOneEach() {
        let exercise = exercise(sets: [
            set(index: 1, completed: true), set(index: 2, completed: true), set(index: 3)
        ])

        #expect(exercise.workingSetCount == 3)
        #expect(exercise.loggedSetCount == 2)
    }

    // MARK: - Numbering

    /// What the circle beside each row reads. Both halves of a pair share a number and are told
    /// apart by the L/R marker, so the user doing three sets a side never sees a "set 4".
    @Test("Test A Pair Shares Its Set Number")
    func testAPairSharesItsSetNumber() {
        let exercise = exercise(sets: threeSetsPerSide)

        let numbers = exercise.workingSets.map { exercise.workingSetNumber(for: $0) }
        let labels = zip(numbers, exercise.workingSets).map { "\($0)\($1.side?.initial ?? "")" }

        #expect(numbers == [1, 1, 2, 2, 3, 3])
        #expect(labels == ["1L", "1R", "2L", "2R", "3L", "3R"])
    }

    /// Warm-ups sit in front of the working sets and are numbered "W", so they must not push the
    /// first working set's number along.
    @Test("Test Warm-Ups Do Not Shift The Set Numbering")
    func testWarmUpsDoNotShiftTheSetNumbering() {
        let working = set(index: 3, side: .left)
        let exercise = exercise(sets: [
            set(index: 1, isWarmup: true),
            set(index: 2, isWarmup: true),
            working,
            set(index: 4, side: .right)
        ])

        #expect(exercise.workingSetNumber(for: working) == 1)
    }

    // MARK: - Set targets

    /// A target describes a set, and a left and a right are one set — so both halves of the first
    /// pair aim at target one, and the second pair does not inherit the first pair's second target.
    @Test("Test Both Halves Of A Pair Take The Same Target")
    func testBothHalvesOfAPairTakeTheSameTarget() {
        let targets = [
            SetTarget(setNumber: 1, minReps: 10, maxReps: 12),
            SetTarget(setNumber: 2, minReps: 8, maxReps: 10),
            SetTarget(setNumber: 3, minReps: 6, maxReps: 8)
        ]
        let exercise = exercise(sets: threeSetsPerSide, targets: targets)

        let matched = exercise.workingSets.map { workingSet in
            exercise.setTargets.first { $0.setNumber == exercise.workingSetNumber(for: workingSet) }
        }

        #expect(matched.map { $0?.minReps } == [10, 10, 8, 8, 6, 6])
    }

    // MARK: - Pairing rows up

    /// What adding and deleting work on. A left set and the right that follows it are one set, so
    /// they travel together.
    @Test("Test A Left And The Right After It Are One Set")
    func testALeftAndTheRightAfterItAreOneSet() {
        let sets = threeSetsPerSide

        #expect(sets.pairedSetIds(for: "set-1") == ["set-1", "set-2"])
        #expect(sets.pairedSetIds(for: "set-2") == ["set-1", "set-2"])
        #expect(sets.pairedSetIds(for: "set-3") == ["set-3", "set-4"])
    }

    @Test("Test A Set With No Side Stands Alone")
    func testASetWithNoSideStandsAlone() {
        let sets = [set(index: 1), set(index: 2)]

        #expect(sets.pairedSetIds(for: "set-1") == ["set-1"])
        #expect(sets.pairedSetIds(for: "missing").isEmpty)
    }

    // MARK: - Last session's figures

    /// A left set inheriting the right arm's last weight sends the user chasing the other arm's
    /// numbers, which is worse than showing them nothing.
    @Test("Test Last Sessions Figures Do Not Cross Sides")
    func testLastSessionsFiguresDoNotCrossSides() {
        let previous = exercise(sets: [
            set(index: 1, side: .left, weightKg: 20),
            set(index: 2, side: .right, weightKg: 22.5)
        ])
        let left = set(index: 1, side: .left)
        let right = set(index: 2, side: .right)
        let current = exercise(sets: [left, right])
        let leftOnly = exercise(sets: [set(index: 1, side: .left, weightKg: 20)])

        #expect(previous.matchingSet(for: left, in: current)?.weightKg == 20)
        #expect(previous.matchingSet(for: right, in: current)?.weightKg == 22.5)
        #expect(leftOnly.matchingSet(for: right, in: current) == nil)
    }

    /// Last time split, this time not: the indices no longer line up, so rows are matched on the
    /// set number. Index 2 here is set 2, where last session's index 2 was set 1's right arm.
    @Test("Test A Row For Both Sides Reads Last Session's Pair By Set Number")
    func testARowForBothSidesReadsLastSessionsPairBySetNumber() {
        let previous = exercise(sets: threeSetsPerSide.enumerated().map { offset, row in
            set(index: row.index, side: row.side, weightKg: 20 + Double(offset))
        })
        let rows = [set(index: 1, side: .both), set(index: 2, side: .both), set(index: 3, side: .both)]
        let current = exercise(sets: rows)

        #expect(rows.map { previous.matchingSet(for: $0, in: current)?.weightKg } == [20, 22, 24])
    }

    /// Everything logged before sides existed has no side at all. That history belongs to both
    /// arms rather than to neither, so it still shows rather than blanking the previous column.
    @Test("Test History From Before Sides Existed Still Shows")
    func testHistoryFromBeforeSidesExistedStillShows() {
        let previous = exercise(sets: [set(index: 1, weightKg: 20)])
        let left = set(index: 1, side: .left)
        let right = set(index: 2, side: .right)
        let current = exercise(sets: [left, right])

        #expect(previous.matchingSet(for: left, in: current)?.weightKg == 20)
        #expect(previous.matchingSet(for: right, in: current)?.weightKg == 20)
    }

    // MARK: - Stored sets

    /// Every set already in someone's history was written without a side key. It has to decode as
    /// a set with no side rather than failing, or their whole training history stops opening.
    @Test("Test A Stored Set With No Side Decodes As Sideless")
    func testAStoredSetWithNoSideDecodesAsSideless() throws {
        let json: [String: Any] = [
            "id": "set-1",
            "author_id": "author-1",
            "index": 1,
            "reps": 8,
            "weight_kg": 60,
            "isWarmup": false,
            "date_created": 1_000_000_000
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        let decoded = try decoder.decode(WorkoutSetModel.self, from: data)

        #expect(decoded.side == nil)
        #expect(decoded.reps == 8)
    }

    @Test("Test A Side Survives A Round Trip")
    func testASideSurvivesARoundTrip() throws {
        let data = try Self.encoder.encode(set(index: 1, side: .right))
        let decoded = try Self.decoder.decode(WorkoutSetModel.self, from: data)

        #expect(decoded.side == .right)
    }

    /// Both sides go out under the key they came in under, so a set written by this build is still
    /// readable by every build that came before it.
    @Test("Test Both Sides Round Trip Under The Stored Key")
    func testBothSidesRoundTripUnderTheStoredKey() throws {
        for side in SetSide.allCases {
            let data = try Self.encoder.encode(set(index: 1, side: side))
            let stored = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

            #expect(stored["side"] as? String == side.rawValue)
            #expect(try Self.decoder.decode(WorkoutSetModel.self, from: data).side == side)
        }
    }

    /// A side this build does not know — written by a later one, or corrupted — must read as no
    /// side rather than throwing. The set is stored as its raw string precisely so the enum never
    /// gets to veto the decode.
    @Test("Test An Unrecognised Stored Side Decodes As Sideless")
    func testAnUnrecognisedStoredSideDecodesAsSideless() throws {
        let data = try JSONSerialization.data(withJSONObject: Self.storedSet(side: "middle"))

        let decoded = try Self.decoder.decode(WorkoutSetModel.self, from: data)

        #expect(decoded.side == nil)
        #expect(decoded.reps == 8)
    }

    /// The reason any of this matters: sets are nested inside the session, so a throw on one
    /// field would take the entire logged workout down with it. One unreadable side costs that
    /// side and nothing else.
    @Test("Test A Session Survives A Set With An Unreadable Side")
    func testASessionSurvivesASetWithAnUnreadableSide() throws {
        let session = WorkoutSessionModel(
            id: "session-1",
            authorId: "author-1",
            name: "Pull",
            dateCreated: date,
            exercises: [exercise(sets: [set(index: 1, side: .left), set(index: 2, side: .right)])]
        )
        var raw = try #require(
            try JSONSerialization.jsonObject(with: Self.encoder.encode(session)) as? [String: Any]
        )
        var exercises = try #require(raw["exercises"] as? [[String: Any]])
        var sets = try #require(exercises[0]["sets"] as? [[String: Any]])
        sets[0]["side"] = "middle"
        exercises[0]["sets"] = sets
        raw["exercises"] = exercises

        let decoded = try Self.decoder.decode(
            WorkoutSessionModel.self,
            from: try JSONSerialization.data(withJSONObject: raw)
        )

        let decodedSets = try #require(decoded.exercises.first?.sets)
        #expect(decodedSets.count == 2)
        #expect(decodedSets.map(\.side) == [nil, .right])
        #expect(decodedSets.map(\.reps) == [10, 10])
    }

    // MARK: - Coding helpers

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }

    private static func storedSet(side: String?) -> [String: Any] {
        var json: [String: Any] = [
            "id": "set-1",
            "author_id": "author-1",
            "index": 1,
            "reps": 8,
            "weight_kg": 60,
            "isWarmup": false,
            "date_created": 1_000_000_000
        ]
        json["side"] = side
        return json
    }

    /// A side written by some later build is not worth failing a decode over — a set whose side
    /// cannot be read is still a set.
    @Test("Test An Unknown Side Reads As None")
    func testAnUnknownSideReadsAsNone() {
        #expect(SetSide(storedValue: "left") == .left)
        #expect(SetSide(storedValue: "middle") == nil)
        #expect(SetSide(storedValue: nil) == nil)
    }
}
