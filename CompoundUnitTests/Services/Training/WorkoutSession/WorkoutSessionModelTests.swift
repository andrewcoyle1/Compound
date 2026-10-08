//
//  WorkoutSessionModelTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 20/09/2026.
//

import Testing
import Foundation
@testable import Compound

/// A logged workout: how it decides what to track, how it carries weights forward from last time,
/// and what editing one does to its start and duration.
///
/// This is the app's central record — everything in Training and most of Analytics reads it — and
/// none of it was covered.
@MainActor
struct WorkoutSessionModelTests {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func set(
        index: Int,
        reps: Int? = 8,
        weightKg: Double? = 60,
        isWarmup: Bool = false,
        completedAt: Date? = nil
    ) -> WorkoutSetModel {
        WorkoutSetModel(
            id: "set-\(index)-\(isWarmup ? "w" : "x")",
            authorId: "author-1",
            index: index,
            reps: reps,
            weightKg: weightKg,
            isWarmup: isWarmup,
            completedAt: completedAt,
            dateCreated: start
        )
    }

    private func exercise(sets: [WorkoutSetModel], name: String = "Bench Press") -> WorkoutExerciseModel {
        WorkoutExerciseModel(
            id: "exercise-1",
            authorId: "author-1",
            templateId: "template-1",
            name: name,
            trackingMode: .weightReps,
            index: 1,
            sets: sets
        )
    }

    private func session(
        exercises: [WorkoutExerciseModel] = [],
        dateCreated: Date? = nil,
        endedAt: Date? = nil
    ) -> WorkoutSessionModel {
        WorkoutSessionModel(
            id: "session-1",
            authorId: "author-1",
            name: "Push Day",
            dateCreated: dateCreated ?? start,
            endedAt: endedAt,
            exercises: exercises
        )
    }

    private func exerciseModel(metrics: [TrackableExerciseMetric]) -> ExerciseModel {
        ExerciseModel(
            authorId: "author-1",
            name: "Test",
            trackableMetrics: metrics,
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

    // MARK: - Initialization

    @Test("Test A New Session Has Not Ended")
    func testANewSessionHasNotEnded() {
        let session = session()

        #expect(session.endedAt == nil)
        #expect(session.deletedAt == nil)
        #expect(session.isRestDay == false)
        #expect(session.likedByUserIds.isEmpty)
    }

    /// Nothing has changed it yet, so "last modified" is when it was made.
    @Test("Test Date Modified Defaults To Date Created")
    func testDateModifiedDefaultsToDateCreated() {
        #expect(session().dateModified == start)
    }

    // MARK: - Choosing what to track

    /// An exercise records whatever its metrics say, and weight wins: a weighted pull-up is a
    /// weight-and-reps exercise even though it also has reps.
    @Test("Test Weight Metrics Give Weight And Reps Tracking")
    func testWeightMetricsGiveWeightAndRepsTracking() {
        for metric in [TrackableExerciseMetric.weight, .weightPerSide, .weightPerSidePersistent, .weightPerSideAssistance] {
            #expect(WorkoutSessionModel.trackingMode(for: exerciseModel(metrics: [metric, .reps])) == .weightReps)
        }
    }

    @Test("Test Reps Alone Give Reps Only Tracking")
    func testRepsAloneGiveRepsOnlyTracking() {
        #expect(WorkoutSessionModel.trackingMode(for: exerciseModel(metrics: [.reps])) == .repsOnly)
        #expect(WorkoutSessionModel.trackingMode(for: exerciseModel(metrics: [.repsPerSide])) == .repsOnly)
    }

    @Test("Test Duration Gives Time Only Tracking")
    func testDurationGivesTimeOnlyTracking() {
        #expect(WorkoutSessionModel.trackingMode(for: exerciseModel(metrics: [.duration])) == .timeOnly)
        #expect(WorkoutSessionModel.trackingMode(for: exerciseModel(metrics: [.durationPerSide])) == .timeOnly)
    }

    @Test("Test Distance Gives Distance And Time Tracking")
    func testDistanceGivesDistanceAndTimeTracking() {
        for metric in [TrackableExerciseMetric.distanceShort, .distanceShortPerSide, .distanceLong] {
            #expect(WorkoutSessionModel.trackingMode(for: exerciseModel(metrics: [metric])) == .distanceTime)
        }
    }

    /// A run records both distance and duration, and should be logged as a run rather than a plank.
    @Test("Test Distance Beats Duration")
    func testDistanceBeatsDuration() {
        #expect(WorkoutSessionModel.trackingMode(for: exerciseModel(metrics: [.duration, .distanceLong])) == .distanceTime)
    }

    @Test("Test An Exercise With No Metrics Falls Back To Reps")
    func testAnExerciseWithNoMetricsFallsBackToReps() {
        #expect(WorkoutSessionModel.trackingMode(for: exerciseModel(metrics: [])) == .repsOnly)
    }

    // MARK: - Default sets

    @Test("Test Default Sets Are Numbered From One")
    func testDefaultSetsAreNumberedFromOne() {
        let sets = WorkoutSessionModel.defaultSets(trackingMode: .weightReps, authorId: "author-1")

        #expect(sets.count == 3)
        #expect(sets.map(\.index) == [1, 2, 3])
        #expect(sets.allSatisfy { !$0.isWarmup })
    }

    @Test("Test Default Sets Honour A Target Count")
    func testDefaultSetsHonourATargetCount() {
        #expect(WorkoutSessionModel.defaultSets(trackingMode: .weightReps, authorId: "a", targetCount: 5).count == 5)
    }

    /// A workout with no sets cannot be logged, so a nonsensical target still gives one.
    @Test("Test There Is Always At Least One Set")
    func testThereIsAlwaysAtLeastOneSet() {
        #expect(WorkoutSessionModel.defaultSets(trackingMode: .weightReps, authorId: "a", targetCount: 0).count == 1)
        #expect(WorkoutSessionModel.defaultSets(trackingMode: .weightReps, authorId: "a", targetCount: -3).count == 1)
    }

    /// Every figure starts blank, timed and distance work included: a stored default of 1:00 or
    /// 400 m would log as though it had been done. The fields show a greyed placeholder instead.
    @Test("Test New Sets Start Empty")
    func testNewSetsStartEmpty() {
        let timed = WorkoutSessionModel.defaultSets(trackingMode: .timeOnly, authorId: "a")
        let distance = WorkoutSessionModel.defaultSets(trackingMode: .distanceTime, authorId: "a")
        let weights = WorkoutSessionModel.defaultSets(trackingMode: .weightReps, authorId: "a")

        #expect(timed.allSatisfy { $0.durationSec == nil })
        #expect(distance.allSatisfy { $0.distanceMeters == nil && $0.durationSec == nil })
        #expect(weights.allSatisfy { $0.weightKg == nil && $0.reps == nil })
    }

    @Test("Test Every Set Gets Its Own Id")
    func testEverySetGetsItsOwnId() {
        let sets = WorkoutSessionModel.defaultSets(trackingMode: .weightReps, authorId: "a", targetCount: 5)

        #expect(Set(sets.map(\.id)).count == 5)
    }

    // MARK: - Carrying weight forward

    /// The first working set is what the next workout starts from — not a warm-up, which would send
    /// the user back to the empty bar every session.
    @Test("Test Previous Weight Comes From The First Working Set")
    func testPreviousWeightComesFromTheFirstWorkingSet() {
        let previous = [
            set(index: 1, reps: 10, weightKg: 20, isWarmup: true),
            set(index: 2, reps: 8, weightKg: 60),
            set(index: 3, reps: 6, weightKg: 70)
        ]

        let estimate = WorkoutSessionModel.estimateWorkingWeightFromPrevious(previousSets: previous)

        #expect(estimate.weightKg == 60)
        #expect(estimate.reps == 8)
    }

    /// A session of nothing but warm-ups still tells us more than nothing.
    @Test("Test Warm-Ups Alone Fall Back To The Last Set")
    func testWarmUpsAloneFallBackToTheLastSet() {
        let previous = [
            set(index: 1, reps: 10, weightKg: 20, isWarmup: true),
            set(index: 2, reps: 10, weightKg: 30, isWarmup: true)
        ]

        let estimate = WorkoutSessionModel.estimateWorkingWeightFromPrevious(previousSets: previous)

        #expect(estimate.weightKg == 30)
        #expect(estimate.reps == 10)
    }

    @Test("Test No Previous Sets Give No Estimate")
    func testNoPreviousSetsGiveNoEstimate() {
        #expect(WorkoutSessionModel.estimateWorkingWeightFromPrevious(previousSets: nil).weightKg == nil)
        #expect(WorkoutSessionModel.estimateWorkingWeightFromPrevious(previousSets: []).reps == nil)
    }

    // MARK: - Rounding to a usable weight

    /// Kilograms round to the half, because that is the smallest plate pair most gyms have.
    @Test("Test Kilograms Round To The Nearest Half")
    func testKilogramsRoundToTheNearestHalf() {
        #expect(WorkoutSessionModel.roundWeightToPreferredUnit(weightKg: 60.2, preferredUnit: .kilograms) == 60)
        #expect(WorkoutSessionModel.roundWeightToPreferredUnit(weightKg: 60.3, preferredUnit: .kilograms) == 60.5)
        #expect(WorkoutSessionModel.roundWeightToPreferredUnit(weightKg: 60.75, preferredUnit: .kilograms) == 61)
    }

    /// Pounds round to the whole, and the result is stored back in kilograms — so a pounds user
    /// gets a round number on screen rather than 61.23 kg converted from 135.
    @Test("Test Pounds Round To A Whole Pound And Store As Kilograms")
    func testPoundsRoundToAWholePoundAndStoreAsKilograms() throws {
        let stored = try #require(WorkoutSessionModel.roundWeightToPreferredUnit(weightKg: 61.2, preferredUnit: .pounds))
        let shown = UnitConversion.convertWeight(stored, to: ExerciseWeightUnit.pounds)

        #expect(abs(shown.rounded() - shown) < 0.0001)
        #expect(abs(stored - 61.2) < 0.3)
    }

    @Test("Test Rounding Nothing Gives Nothing")
    func testRoundingNothingGivesNothing() {
        #expect(WorkoutSessionModel.roundWeightToPreferredUnit(weightKg: nil, preferredUnit: .kilograms) == nil)
    }

    @Test("Test A Weight Already On The Increment Is Left Alone")
    func testAWeightAlreadyOnTheIncrementIsLeftAlone() {
        #expect(WorkoutSessionModel.roundWeightToPreferredUnit(weightKg: 60, preferredUnit: .kilograms) == 60)
        #expect(WorkoutSessionModel.roundWeightToPreferredUnit(weightKg: 62.5, preferredUnit: .kilograms) == 62.5)
    }

    // MARK: - Editing a session

    @Test("Test Ending A Session Records When")
    func testEndingASessionRecordsWhen() {
        var session = session()
        let end = start.addingTimeInterval(3600)

        session.endSession(at: end)

        #expect(session.endedAt == end)
        #expect(session.dateModified == end)
    }

    /// Moving a workout to yesterday should not make it an hour longer or shorter.
    @Test("Test Moving A Session Keeps How Long It Took")
    func testMovingASessionKeepsHowLongItTook() throws {
        var session = session(endedAt: start.addingTimeInterval(3600))
        let newStart = start.addingTimeInterval(-86400)

        session.updateStart(newStart)

        #expect(session.dateCreated == newStart)
        #expect(try #require(session.endedAt).timeIntervalSince(newStart) == 3600)
    }

    @Test("Test Moving An Unfinished Session Leaves It Unfinished")
    func testMovingAnUnfinishedSessionLeavesItUnfinished() {
        var session = session()

        session.updateStart(start.addingTimeInterval(-86400))

        #expect(session.endedAt == nil)
    }

    @Test("Test Setting A Duration Measures From The Start")
    func testSettingADurationMeasuresFromTheStart() {
        var session = session()

        session.updateDuration(1800)

        #expect(session.endedAt == start.addingTimeInterval(1800))
    }

    /// A zero or negative duration would put the end before the beginning.
    @Test("Test A Nonsensical Duration Is Refused")
    func testANonsensicalDurationIsRefused() {
        var session = session(endedAt: start.addingTimeInterval(3600))

        session.updateDuration(0)
        #expect(session.endedAt == start.addingTimeInterval(3600))

        session.updateDuration(-60)
        #expect(session.endedAt == start.addingTimeInterval(3600))
    }

    @Test("Test Replacing The Exercises Marks The Session Modified")
    func testReplacingTheExercisesMarksTheSessionModified() {
        var session = session()
        let before = session.dateModified

        session.updateExercises([exercise(sets: [set(index: 1)])])

        #expect(session.exercises.count == 1)
        #expect(session.dateModified > before)
    }

    // MARK: - Deloads

    @Test("Test A Deload Takes Every Weight To Sixty-Five Percent")
    func testADeloadTakesEveryWeightToSixtyFivePercent() {
        var session = session(exercises: [
            exercise(sets: [set(index: 1, weightKg: 100), set(index: 2, weightKg: 80)])
        ])

        session.applyDeloadWeightReduction()

        #expect(session.exercises[0].sets[0].weightKg == 65)
        #expect(session.exercises[0].sets[1].weightKg == 52)
    }

    /// Bodyweight and timed work carry no weight, and a deload must not invent one.
    @Test("Test A Deload Leaves Unweighted Sets Alone")
    func testADeloadLeavesUnweightedSetsAlone() {
        var session = session(exercises: [
            exercise(sets: [set(index: 1, weightKg: nil), set(index: 2, weightKg: 100)])
        ])

        session.applyDeloadWeightReduction()

        #expect(session.exercises[0].sets[0].weightKg == nil)
        #expect(session.exercises[0].sets[1].weightKg == 65)
    }

    @Test("Test A Deload On An Empty Session Does Nothing")
    func testADeloadOnAnEmptySessionDoesNothing() {
        var session = session()

        session.applyDeloadWeightReduction()

        #expect(session.exercises.isEmpty)
    }

    // MARK: - WP-S1 set plan

    /// A drop on a per-side set is per-side too, and a set with no weight yet has drops with none.
    @Test("Test Planned Drops Take Their Set's Side And Leave A Missing Weight Missing")
    func testPlannedDropsTakeSideAndMissingWeight() {
        let targets = [SetTarget(setNumber: 1, setType: .drop, dropCount: 2), SetTarget(setNumber: 2)]
        let sets = WorkoutSessionModel.defaultSets(
            trackingMode: .weightReps, authorId: "author-1", targetCount: 2, perSide: true, setTargets: targets
        )

        let planned = WorkoutSessionModel.applyingSetPlan(to: sets, setTargets: targets, authorId: "author-1")

        #expect(planned.count == 4)
        #expect(planned.allSatisfy { $0.side == .both })
        #expect(planned.allSatisfy { $0.weightKg == nil })
        #expect(planned[1].parentSetId == planned[0].id && planned[2].parentSetId == planned[0].id)
        #expect(planned[3].parentSetId == nil)
    }

    /// No count, or a nonsense one, adds nothing; a set past the targets is left alone.
    @Test("Test A Plan Without Counts Adds No Sub-Sets")
    func testPlanWithoutCountsAddsNothing() {
        let targets = [
            SetTarget(setNumber: 1, setType: .drop),
            SetTarget(setNumber: 2, setType: .myo, miniSetCount: -1)
        ]
        let sets = WorkoutSessionModel.defaultSets(trackingMode: .weightReps, authorId: "author-1", targetCount: 3, setTargets: targets)

        let planned = WorkoutSessionModel.applyingSetPlan(to: sets, setTargets: targets, authorId: "author-1")

        #expect(planned.map(\.id) == sets.map(\.id))
    }

    /// The plan's AMRAP target stands unless the prefill already raised it.
    @Test("Test An AMRAP Target Raised By The Prefill Is Kept")
    func testRaisedAMRAPTargetIsKept() {
        let targets = [SetTarget(setNumber: 1, setType: .amrap, amrapTargetReps: 8)]
        var sets = WorkoutSessionModel.defaultSets(trackingMode: .weightReps, authorId: "author-1", targetCount: 1, setTargets: targets)
        #expect(WorkoutSessionModel.applyingSetPlan(to: sets, setTargets: targets, authorId: "author-1")[0].targetReps == 8)

        sets[0].targetReps = 9

        #expect(WorkoutSessionModel.applyingSetPlan(to: sets, setTargets: targets, authorId: "author-1")[0].targetReps == 9)
    }

    @Test("Test A Set's Target Reps Round-Trip And Old Sets Decode Without One")
    func testTargetRepsCoding() throws {
        var set = WorkoutSetModel(id: "s1", authorId: "author-1", index: 1, kind: .amrap, isWarmup: false, dateCreated: start)
        var json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(set)) as? [String: Any])
        #expect(json["target_reps"] == nil)
        #expect(try JSONDecoder().decode(WorkoutSetModel.self, from: JSONSerialization.data(withJSONObject: json)).targetReps == nil)

        set.targetReps = 8
        json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(set)) as? [String: Any])

        #expect(json["target_reps"] as? Int == 8)
        #expect(try JSONDecoder().decode(WorkoutSetModel.self, from: JSONEncoder().encode(set)).targetReps == 8)
    }
}
