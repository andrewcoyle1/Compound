//
//  ProgressionEngineTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// Double progression, in the only place it is decided.
///
/// The engine is a pure function of its input — no gym, no managers, no clock — so every case
/// here is the algorithm itself rather than a screen exercising it. What it has to get right:
///
/// - **Reaching the top of the range earns weight**, and adding weight drops the reps back to the
///   bottom of it. Which set has to reach the top is the difference between the two adjustment
///   modes: weight-first takes one, reps-first wants them all.
/// - **A miss holds, two misses deload.** One bad session is a bad day; the second one in a row,
///   at the same weight or heavier, is the signal.
/// - **Effort overrides the rep count.** A set that hit the top of the range at an RPE harder
///   than it was prescribed did not earn weight.
/// - **Rounding is the gym's, not the algorithm's.** Where the rounding swallows the increment
///   whole, the engine adds a second one rather than suggesting the weight just lifted.
struct ProgressionEngineTests {

    private let engine = ProgressionEngine()
    private let start = Date(timeIntervalSince1970: 1_000_000)

    // MARK: - Helpers

    /// Rounds to the half kilo, which is what the app does for a kg user on free weights.
    private let roundToHalfKg: (Double) -> Double = { ($0 * 2).rounded() / 2 }

    /// A machine that only moves in fives, and only ever downwards when it is between two.
    private let roundToFiveKgDown: (Double) -> Double = { ($0 / 5).rounded(.down) * 5 }

    // A logged set is three numbers, and naming them beats three parallel arrays.
    private func sets(
        // swiftlint:disable:next large_tuple
        _ values: [(kg: Double?, reps: Int?, rpe: Double?)],
        completed: Bool = true
    ) -> [WorkoutSetModel] {
        values.enumerated().map { index, value in
            WorkoutSetModel(
                id: "set-\(index + 1)",
                authorId: "author-1",
                index: index + 1,
                reps: value.reps,
                weightKg: value.kg,
                rpe: value.rpe,
                isWarmup: false,
                completedAt: completed ? start : nil,
                dateCreated: start
            )
        }
    }

    private func timedSets(durations: [Int], distances: [Double?] = [], completed: Bool = true) -> [WorkoutSetModel] {
        durations.enumerated().map { index, duration in
            WorkoutSetModel(
                id: "set-\(index + 1)",
                authorId: "author-1",
                index: index + 1,
                durationSec: duration,
                distanceMeters: index < distances.count ? distances[index] : nil,
                isWarmup: false,
                completedAt: completed ? start : nil,
                dateCreated: start
            )
        }
    }

    private func targets(min: Int?, max: Int?, count: Int, rir: Int? = nil) -> [SetTarget] {
        (1...count).map { number in
            SetTarget(id: "target-\(number)", setNumber: number, minReps: min, maxReps: max, rirTarget: rir)
        }
    }

    private func input(
        mode: TrackingMode = .weightReps,
        targets: [SetTarget] = [],
        history: [[WorkoutSetModel]],
        adjustmentMode: ProgressionAdjustmentMode = .weightFirst,
        round: ((Double) -> Double)? = nil,
        incrementKg: Double = 2.5
    ) -> ProgressionInput {
        ProgressionInput(
            trackingMode: mode,
            setTargets: targets,
            history: history.map { ProgressionHistorySession(workingSets: $0) },
            adjustmentMode: adjustmentMode,
            roundWeight: round ?? roundToHalfKg,
            minimumIncrementKg: incrementKg
        )
    }

    // MARK: - Nothing to go on

    /// The engine never invents a starting weight: with no history it says so and suggests
    /// nothing at all, and the caller falls back to the template's own defaults.
    @Test("Test No History Suggests Nothing")
    func testNoHistorySuggestsNothing() {
        let suggestion = engine.suggest(input(targets: targets(min: 8, max: 12, count: 3), history: []))

        #expect(suggestion.rationale == .noHistory)
        #expect(suggestion.sets.count == 3)
        let allEmpty = suggestion.sets.allSatisfy { $0.weightKg == nil && $0.reps == nil && $0.durationSec == nil && $0.distanceMeters == nil }
        #expect(allEmpty)
    }

    // MARK: - Earning weight

    /// Weight-first: a majority of sets at the top of the range is enough to add weight, and
    /// every set drops back to the bottom of it. The one that fell short is not a miss.
    @Test("Test Weight First Adds Weight When Most Sets Reach The Top")
    func testWeightFirstAddsWeightWhenMostSetsReachTheTop() {
        let suggestion = engine.suggest(input(
            targets: targets(min: 8, max: 12, count: 4),
            history: [sets([(60, 12, 8), (60, 12, 8), (60, 12, 8), (60, 10, 8)])]
        ))

        #expect(suggestion.rationale == .progressWeight)
        #expect(suggestion.sets == [
            SuggestedSet(weightKg: 62.5, reps: 8),
            SuggestedSet(weightKg: 62.5, reps: 8),
            SuggestedSet(weightKg: 62.5, reps: 8),
            SuggestedSet(weightKg: 62.5, reps: 8)
        ])
    }

    /// One good set followed by a fade is a weight that is not ready. Weight-first still adds a
    /// rep to the sets that have room rather than a plate to all of them.
    @Test("Test Weight First Adds Reps When Only One Set Reaches The Top")
    func testWeightFirstAddsRepsWhenOnlyOneSetReachesTheTop() {
        let suggestion = engine.suggest(input(
            targets: targets(min: 8, max: 12, count: 4),
            history: [sets([(60, 12, nil), (60, 10, nil), (60, 9, nil), (60, 8, nil)])]
        ))

        #expect(suggestion.rationale == .addReps)
        #expect(suggestion.sets == [
            SuggestedSet(weightKg: 60, reps: 12),
            SuggestedSet(weightKg: 60, reps: 11),
            SuggestedSet(weightKg: 60, reps: 10),
            SuggestedSet(weightKg: 60, reps: 9)
        ])
    }

    /// Exactly half is not a majority: two of four at the top holds the weight.
    @Test("Test Weight First Needs More Than Half The Sets At The Top")
    func testWeightFirstNeedsMoreThanHalfTheSetsAtTheTop() {
        let suggestion = engine.suggest(input(
            targets: targets(min: 8, max: 12, count: 4),
            history: [sets([(60, 12, nil), (60, 12, nil), (60, 10, nil), (60, 10, nil)])]
        ))

        #expect(suggestion.rationale == .addReps)
    }

    /// The same session under reps-first: the other two sets have not caught up, so it is a rep
    /// each rather than weight.
    @Test("Test Reps First Adds A Rep Until Every Set Has Caught Up")
    func testRepsFirstAddsARepUntilEverySetHasCaughtUp() {
        let suggestion = engine.suggest(input(
            targets: targets(min: 8, max: 12, count: 3),
            history: [sets([(60, 12, nil), (60, 10, nil), (60, 9, nil)])],
            adjustmentMode: .repsFirst
        ))

        #expect(suggestion.rationale == .addReps)
        #expect(suggestion.sets == [
            SuggestedSet(weightKg: 60, reps: 12),
            SuggestedSet(weightKg: 60, reps: 11),
            SuggestedSet(weightKg: 60, reps: 10)
        ])
    }

    /// Reps-first with every set at the top: now the weight moves.
    @Test("Test Reps First Adds Weight Once Every Set Is At The Top")
    func testRepsFirstAddsWeightOnceEverySetIsAtTheTop() {
        let suggestion = engine.suggest(input(
            targets: targets(min: 8, max: 12, count: 3),
            history: [sets([(60, 12, 8), (60, 12, 8), (60, 12, 8)])],
            adjustmentMode: .repsFirst
        ))

        #expect(suggestion.rationale == .progressWeight)
        let allProgressed = suggestion.sets.allSatisfy { $0 == SuggestedSet(weightKg: 62.5, reps: 8) }
        #expect(allProgressed)
    }

    // MARK: - Missing

    /// One set below the bottom of the range repeats the session exactly. Nothing about a single
    /// bad set says the weight was wrong.
    @Test("Test One Miss Repeats The Session Exactly")
    func testOneMissRepeatsTheSessionExactly() {
        let suggestion = engine.suggest(input(
            targets: targets(min: 8, max: 12, count: 3),
            history: [sets([(60, 12, nil), (60, 8, nil), (60, 6, nil)])]
        ))

        #expect(suggestion.rationale == .hold)
        #expect(suggestion.sets == [
            SuggestedSet(weightKg: 60, reps: 12),
            SuggestedSet(weightKg: 60, reps: 8),
            SuggestedSet(weightKg: 60, reps: 6)
        ])
    }

    /// Two sessions running below the range, the second at the same weight: the weight is
    /// worked back from each set's estimated one-rep max to the bottom of the range with two reps
    /// in reserve. 60 kg × 7 is 74 kg, and 74 / (1 + 10/30) is 55.5 kg; 60 × 6 gives 54 kg.
    @Test("Test Two Missed Sessions Reset From The Estimated One-Rep Max")
    func testTwoMissedSessionsDeload() {
        let suggestion = engine.suggest(input(
            targets: targets(min: 8, max: 12, count: 3),
            history: [
                sets([(60, 7, nil), (60, 7, nil), (60, 6, nil)]),
                sets([(60, 7, nil), (60, 6, nil), (60, 6, nil)])
            ]
        ))

        #expect(suggestion.rationale == .deload)
        #expect(suggestion.sets == [
            SuggestedSet(weightKg: 55.5, reps: 8),
            SuggestedSet(weightKg: 55.5, reps: 8),
            SuggestedSet(weightKg: 54, reps: 8)
        ])
    }

    /// The derived weight is kept within 5–15 % under the weight missed: a near miss still takes
    /// something off, and a bad one never more than 15 %.
    @Test("Test A Reset Takes Between Five And Fifteen Per Cent Off")
    func testAResetIsClamped() {
        let nearMiss = engine.suggest(input(
            targets: targets(min: 5, max: 6, count: 1, rir: 0),
            history: [sets([(100, 4, nil)]), sets([(100, 4, nil)])]
        ))
        // 100 × (1 + 4/30) = 113.3, and 113.3 / (1 + 5/30) = 97.1: held to 95.
        #expect(nearMiss.sets == [SuggestedSet(weightKg: 95, reps: 5)])

        let badMiss = engine.suggest(input(
            targets: targets(min: 10, max: 12, count: 1, rir: 3),
            history: [sets([(100, 2, nil)]), sets([(100, 2, nil)])]
        ))
        #expect(badMiss.sets == [SuggestedSet(weightKg: 85, reps: 10)])
    }

    /// Past ten reps to failure there is no estimate to work back from, so the reset takes the
    /// ten per cent it always did.
    @Test("Test A Reset Without An Estimate Takes Ten Per Cent")
    func testAResetWithoutAnEstimateTakesTenPerCent() {
        let suggestion = engine.suggest(input(
            targets: targets(min: 12, max: 15, count: 1),
            history: [sets([(60, 11, nil)]), sets([(60, 11, nil)])]
        ))

        #expect(suggestion.rationale == .deload)
        #expect(suggestion.sets == [SuggestedSet(weightKg: 54, reps: 12)])
    }

    /// Misses logged at an RPE under 9.5 left reps in reserve: the set was stopped short, not
    /// failed, so it holds rather than resets.
    @Test("Test Misses Stopped Short Of Failure Do Not Reset")
    func testMissesStoppedShortDoNotReset() {
        let suggestion = engine.suggest(input(
            targets: targets(min: 8, max: 12, count: 2),
            history: [
                sets([(60, 7, 8), (60, 7, 8)]),
                sets([(60, 7, 8), (60, 6, 8)])
            ]
        ))

        #expect(suggestion.rationale == .hold)
    }

    /// The earlier misses were at a lighter weight, so they are not the same failure repeating —
    /// the user has already moved up since. Hold rather than deload below where they started.
    @Test("Test Misses At A Lighter Weight Do Not Deload")
    func testMissesAtALighterWeightDoNotDeload() {
        let suggestion = engine.suggest(input(
            targets: targets(min: 8, max: 12, count: 3),
            history: [
                sets([(60, 7, nil), (60, 7, nil), (60, 6, nil)]),
                sets([(55, 7, nil), (55, 6, nil), (55, 6, nil)])
            ]
        ))

        #expect(suggestion.rationale == .hold)
    }

    // MARK: - Effort

    /// With no RPE logged, reaching the top once is not enough: it has to happen on two sessions
    /// running at this weight before weight goes on.
    @Test("Test Without An RPE The Top Must Be Reached Twice")
    func testWithoutAnRPETheTopMustBeReachedTwice() {
        let once = engine.suggest(input(
            targets: targets(min: 8, max: 12, count: 2),
            history: [sets([(60, 12, nil), (60, 12, nil)]), sets([(60, 11, nil), (60, 10, nil)])]
        ))
        #expect(once.rationale == .addReps)
        #expect(once.sets.map(\.weightKg) == [60, 60])

        let twice = engine.suggest(input(
            targets: targets(min: 8, max: 12, count: 2),
            history: [sets([(60, 12, nil), (60, 12, nil)]), sets([(60, 12, nil), (60, 12, nil)])]
        ))
        #expect(twice.rationale == .progressWeight)
        #expect(twice.sets.map(\.weightKg) == [62.5, 62.5])

        // Reaching the top at a lighter weight last time is not this weight's second time.
        let lighter = engine.suggest(input(
            targets: targets(min: 8, max: 12, count: 1),
            history: [sets([(60, 12, nil)]), sets([(57.5, 12, nil)])]
        ))
        #expect(lighter.rationale == .addReps)
    }

    /// A compound lift with no RIR target is held to one rep in reserve: RPE 10 at the top of the
    /// range does not earn weight, RPE 9.5 does.
    @Test("Test A Compound Lift Without A Target Needs A Rep In Reserve")
    func testACompoundLiftNeedsARepInReserve() {
        func suggestion(rpe: Double, type: ExerciseType?) -> ProgressionSuggestion {
            engine.suggest(ProgressionInput(
                trackingMode: .weightReps,
                setTargets: targets(min: 8, max: 12, count: 1),
                history: [ProgressionHistorySession(workingSets: sets([(60, 12, rpe)]))],
                adjustmentMode: .weightFirst,
                roundWeight: roundToHalfKg,
                minimumIncrementKg: 2.5,
                exerciseType: type
            ))
        }

        #expect(suggestion(rpe: 10, type: .compoundUpper).rationale == .addReps)
        #expect(suggestion(rpe: 9.5, type: .compoundUpper).rationale == .progressWeight)
        #expect(suggestion(rpe: 10, type: .isolationUpper).rationale == .progressWeight)
        #expect(suggestion(rpe: 10, type: nil).rationale == .progressWeight)
    }

    /// The top of the range was reached, but at an RPE harder than the two reps in reserve the
    /// target asked for. Reps rather than weight until it comes back down.
    @Test("Test An Over-Effort Set Does Not Earn Weight")
    func testAnOverEffortSetDoesNotEarnWeight() {
        let suggestion = engine.suggest(input(
            targets: targets(min: 8, max: 12, count: 3, rir: 2),
            history: [sets([(60, 12, 9.5), (60, 10, 8), (60, 9, 8)])]
        ))

        #expect(suggestion.rationale == .addReps)
    }

    // MARK: - Ranges and rounding

    /// With no target to read, the range is derived from what was done: last time's reps as the
    /// bottom, two more as the top.
    @Test("Test A Missing Rep Range Is Derived From Last Time")
    func testAMissingRepRangeIsDerivedFromLastTime() {
        let suggestion = engine.suggest(input(history: [sets([(60, 10, nil)])]))

        #expect(suggestion.rationale == .addReps)
        #expect(suggestion.sets == [SuggestedSet(weightKg: 60, reps: 11)])
    }

    /// A 2.5 kg step on a machine that only moves in fives rounds straight back to the weight
    /// just lifted, so a second increment goes on rather than suggesting no change at all.
    @Test("Test Rounding That Swallows The Increment Adds A Second One")
    func testRoundingThatSwallowsTheIncrementAddsASecondOne() {
        let suggestion = engine.suggest(input(
            targets: targets(min: 8, max: 12, count: 1),
            history: [sets([(60, 12, 8)])],
            round: roundToFiveKgDown
        ))

        #expect(suggestion.rationale == .progressWeight)
        #expect(suggestion.sets == [SuggestedSet(weightKg: 65, reps: 8)])
    }

    /// The step is a share of the working weight by exercise type: 5 % on a lower-body compound,
    /// so 140 kg goes to 147 kg rather than 142.5 kg.
    @Test("Test The Step Is A Share Of The Working Weight")
    func testTheStepIsAShareOfTheWorkingWeight() {
        let squat = engine.suggest(ProgressionInput(
            trackingMode: .weightReps,
            setTargets: targets(min: 5, max: 8, count: 1),
            history: [ProgressionHistorySession(workingSets: sets([(140, 8, 8)]))],
            adjustmentMode: .weightFirst,
            roundWeight: roundToHalfKg,
            minimumIncrementKg: 2.5,
            exerciseType: .compoundLower
        ))

        #expect(squat.sets == [SuggestedSet(weightKg: 147, reps: 5)])
    }

    /// 2 kg on a 12 kg lateral raise is a 17 % jump, more than the 10 % allowed: a rep more
    /// instead, until the reps done carry 14 kg for 8 (15 reps at 12 kg, by Epley).
    @Test("Test A Step Too Big For The Weight Adds A Rep Instead")
    func testAStepTooBigAddsARepInstead() {
        func suggestion(reps: Int) -> ProgressionSuggestion {
            engine.suggest(ProgressionInput(
                trackingMode: .weightReps,
                setTargets: targets(min: 8, max: 12, count: 1),
                history: [ProgressionHistorySession(workingSets: sets([(12, reps, 8)]))],
                adjustmentMode: .weightFirst,
                roundWeight: { ($0 / 2).rounded() * 2 },
                minimumIncrementKg: 2,
                exerciseType: .isolationUpper
            ))
        }

        #expect(suggestion(reps: 12).rationale == .addReps)
        #expect(suggestion(reps: 12).sets == [SuggestedSet(weightKg: 12, reps: 13)])
        #expect(suggestion(reps: 14).sets == [SuggestedSet(weightKg: 12, reps: 15)])
        #expect(suggestion(reps: 15).rationale == .progressWeight)
        #expect(suggestion(reps: 15).sets == [SuggestedSet(weightKg: 14, reps: 8)])
    }

    /// Each set progresses from its own reference set, so a session logged with descending
    /// weights stays descending rather than collapsing onto the top set.
    @Test("Test Each Set Progresses From Its Own Reference")
    func testEachSetProgressesFromItsOwnReference() {
        let suggestion = engine.suggest(input(
            targets: targets(min: 8, max: 12, count: 3),
            history: [sets([(100, 12, 8), (90, 12, 8), (80, 12, 8)])]
        ))

        #expect(suggestion.sets.map(\.weightKg) == [102.5, 92.5, 82.5])
    }

    /// A drop set is an intensity technique the template author designed. It is prefilled with
    /// what was done last time and never progressed, even when the exercise as a whole is.
    @Test("Test A Drop Set Is Prefilled But Never Progressed")
    func testADropSetIsPrefilledButNeverProgressed() {
        var setTargets = targets(min: 8, max: 12, count: 3)
        setTargets[2] = SetTarget(id: "target-3", setNumber: 3, minReps: 8, maxReps: 12, setType: .drop)

        let suggestion = engine.suggest(input(
            targets: setTargets,
            history: [sets([(60, 12, 8), (60, 12, 8), (60, 9, 8)])]
        ))

        #expect(suggestion.rationale == .progressWeight)
        #expect(suggestion.sets == [
            SuggestedSet(weightKg: 62.5, reps: 8),
            SuggestedSet(weightKg: 62.5, reps: 8),
            SuggestedSet(weightKg: 60, reps: 9)
        ])
    }

    /// WP-P2: partials, a stretch and a hold are intensity techniques like a drop.
    @Test("Test Partials, Stretch And Hold Sets Are Prefilled But Never Progressed", arguments: [SetTargetSetType.partials, .stretch, .hold])
    func testTechniqueSetsAreNeverProgressed(setType: SetTargetSetType) {
        var setTargets = targets(min: 8, max: 12, count: 3)
        setTargets[2] = SetTarget(id: "target-3", setNumber: 3, minReps: 8, maxReps: 12, setType: setType)

        let suggestion = engine.suggest(input(
            targets: setTargets,
            history: [sets([(60, 12, 8), (60, 12, 8), (60, 9, 8)])]
        ))

        #expect(suggestion.rationale == .progressWeight)
        #expect(suggestion.sets.last == SuggestedSet(weightKg: 60, reps: 9))
    }

    /// More sets were logged than the template has targets for, so the last target carries on
    /// applying rather than the extra sets losing their range.
    @Test("Test The Last Target Applies To Sets Past The End Of The List")
    func testTheLastTargetAppliesToSetsPastTheEndOfTheList() {
        let setTargets = [
            SetTarget(id: "target-1", setNumber: 1, minReps: 8, maxReps: 12),
            SetTarget(id: "target-2", setNumber: 2, minReps: 5, maxReps: 8)
        ]

        let suggestion = engine.suggest(input(
            targets: setTargets,
            history: [sets([(60, 12, 8), (60, 8, 8), (60, 8, 8)])]
        ))

        #expect(suggestion.rationale == .progressWeight)
        #expect(suggestion.sets.map(\.reps) == [8, 5, 5])
    }

    // MARK: - Other tracking modes

    /// Bodyweight work cannot add weight, so reaching the top of the range raises the range
    /// instead.
    @Test("Test Reps Only Work Raises The Range")
    func testRepsOnlyWorkRaisesTheRange() {
        let suggestion = engine.suggest(input(
            mode: .repsOnly,
            targets: targets(min: 8, max: 12, count: 3),
            history: [sets([(nil, 12, 8), (nil, 12, 8), (nil, 12, 8)])]
        ))

        #expect(suggestion.rationale == .progressWeight)
        #expect(suggestion.sets.map(\.reps) == [13, 13, 13])
        let noWeights = suggestion.sets.allSatisfy { $0.weightKg == nil }
        #expect(noWeights)
    }

    /// Timed work grows by a tenth, rounded to something a clock can be set to.
    @Test("Test Timed Work Grows By A Tenth")
    func testTimedWorkGrowsByATenth() {
        let suggestion = engine.suggest(input(mode: .timeOnly, history: [timedSets(durations: [60, 60])]))

        #expect(suggestion.rationale == .progressWeight)
        #expect(suggestion.sets.map(\.durationSec) == [65, 65])
    }

    /// A set left unfinished says the time was already at the limit, so it holds.
    @Test("Test Timed Work Holds When A Set Was Not Finished")
    func testTimedWorkHoldsWhenASetWasNotFinished() {
        let suggestion = engine.suggest(input(
            mode: .timeOnly,
            history: [timedSets(durations: [60, 60], completed: false)]
        ))

        #expect(suggestion.rationale == .hold)
        #expect(suggestion.sets.map(\.durationSec) == [60, 60])
    }

    /// Distance grows by a twentieth; however long it took is carried over untouched.
    @Test("Test Distance Work Grows By A Twentieth")
    func testDistanceWorkGrowsByATwentieth() {
        let suggestion = engine.suggest(input(
            mode: .distanceTime,
            history: [timedSets(durations: [300], distances: [1000])]
        ))

        #expect(suggestion.sets.map(\.distanceMeters) == [1050])
        #expect(suggestion.sets.map(\.durationSec) == [300])
    }

    // MARK: - Live adjustment

    private func adjustment(
        completedReps: Int,
        rpe: Double? = nil,
        target: SetTarget? = SetTarget(id: "target-1", setNumber: 1, minReps: 8, maxReps: 12),
        remainingCount: Int = 2
    ) -> [SuggestedSet?] {
        let completed = sets([(60, completedReps, rpe)])[0]
        // swiftlint:disable:next large_tuple
        let row: (kg: Double?, reps: Int?, rpe: Double?) = (60, 8, nil)
        let remaining = sets(Array(repeating: row, count: remainingCount), completed: false)
        return engine.adjustRemaining(
            completed: completed,
            target: target,
            remaining: remaining,
            mode: .weightReps,
            rounding: ProgressionRounding(round: roundToHalfKg, minimumIncrementKg: 2.5)
        )
    }

    /// Missing the bottom of the range by two or more takes five per cent off what is left: the
    /// weight was wrong for today, and there is no sense grinding out the rest of it.
    @Test("Test Missing By Two Lightens The Remaining Sets")
    func testMissingByTwoLightensTheRemainingSets() {
        #expect(adjustment(completedReps: 6) == [
            SuggestedSet(weightKg: 57, reps: 8),
            SuggestedSet(weightKg: 57, reps: 8)
        ])
    }

    /// Missing by one is close enough to keep the weight and simply aim at the bottom of the
    /// range again.
    @Test("Test Missing By One Keeps The Weight")
    func testMissingByOneKeepsTheWeight() {
        #expect(adjustment(completedReps: 7) == [
            SuggestedSet(weightKg: 60, reps: 8),
            SuggestedSet(weightKg: 60, reps: 8)
        ])
    }

    /// Beating the top of the range by two at an easy RPE earns weight straight away rather than
    /// waiting for next week.
    @Test("Test Beating The Range Easily Adds Weight To The Remaining Sets")
    func testBeatingTheRangeEasilyAddsWeightToTheRemainingSets() {
        #expect(adjustment(completedReps: 14, rpe: 7) == [
            SuggestedSet(weightKg: 62.5, reps: 8),
            SuggestedSet(weightKg: 62.5, reps: 8)
        ])
    }

    /// The same rep count at an RPE of 9 was not easy, whatever the number says, so nothing
    /// changes.
    @Test("Test Beating The Range At A Hard RPE Changes Nothing")
    func testBeatingTheRangeAtAHardRPEChangesNothing() {
        let adjusted = adjustment(completedReps: 14, rpe: 9)
        let allUnchanged = adjusted.allSatisfy { $0 == nil }
        #expect(allUnchanged)
    }

    /// A set within its range says nothing worth acting on.
    @Test("Test A Set Inside Its Range Changes Nothing")
    func testASetInsideItsRangeChangesNothing() {
        let adjusted = adjustment(completedReps: 10)
        let allUnchanged = adjusted.allSatisfy { $0 == nil }
        #expect(allUnchanged)
    }

    /// Only weight and reps are adjusted live in this version.
    @Test("Test Live Adjustment Leaves Other Tracking Modes Alone")
    func testLiveAdjustmentLeavesOtherTrackingModesAlone() {
        let completed = sets([(nil, 6, nil)])[0]
        let remaining = sets([(nil, 8, nil), (nil, 8, nil)], completed: false)

        let adjusted = engine.adjustRemaining(
            completed: completed,
            target: SetTarget(id: "target-1", setNumber: 1, minReps: 8, maxReps: 12),
            remaining: remaining,
            mode: .repsOnly,
            rounding: ProgressionRounding(round: roundToHalfKg, minimumIncrementKg: 2.5)
        )

        let allUnchanged = adjusted.allSatisfy { $0 == nil }
        #expect(allUnchanged)
    }
}
