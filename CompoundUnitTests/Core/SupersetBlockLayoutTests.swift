//
//  SupersetBlockLayoutTests.swift
//  CompoundUnitTests
//
//  The superset card's table: which exercises it holds, the order of its rows and their badges,
//  and when one row of column headings fits them all. `ActiveWorkout+SupersetBlock`.
//

import Testing
import Foundation
@testable import Compound

struct SupersetBlockLayoutTests {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    /// Warm-ups first (`loggedWarmups` of them logged), then `working` sets; ids are
    /// "<exercise>-w<n>" and "<exercise>-<n>". `split` makes each working set a left/right pair.
    private func exercise(
        _ id: String,
        working: Int = 2,
        warmups: Int = 0,
        loggedWarmups: Int = 0,
        split: Bool = false,
        mode: TrackingMode = .weightReps,
        group: String? = "g"
    ) -> WorkoutExerciseModel {
        let warm = (0..<warmups).map { index in
            WorkoutSetModel(
                id: "\(id)-w\(index + 1)", authorId: "a", index: index + 1, reps: 5, weightKg: 40,
                isWarmup: true, completedAt: index < loggedWarmups ? start : nil, dateCreated: start
            )
        }
        let sides: [SetSide?] = split ? [.left, .right] : [nil]
        let sets = (0..<working).flatMap { number in
            sides.map { side in
                WorkoutSetModel(
                    id: "\(id)-\(number + 1)\(side?.initial ?? "")", authorId: "a", index: warmups + number + 1,
                    reps: 8, weightKg: 80, side: side, isWarmup: false, dateCreated: start
                )
            }
        }
        return WorkoutExerciseModel(
            id: id, authorId: "a", templateId: "t-\(id)", name: id.uppercased(), trackingMode: mode,
            index: 1, sets: warm + sets, supersetGroupId: group
        )
    }

    private func layout(_ rows: [SupersetBlockRow]) -> [String] {
        rows.map { row in
            switch row.kind {
            case .loggedWarmups: "warmups:\(row.exerciseId)"
            case .set(let id, let badge): "\(badge):\(id)"
            }
        }
    }

    // MARK: - Which card

    @Test("Test Only A Superset Of Two Or More Is A Block")
    func testOnlyASupersetOfTwoOrMoreIsABlock() {
        let exercises = [exercise("a", group: nil), exercise("b"), exercise("c", group: "h"), exercise("d")]

        #expect(ActiveWorkout.supersetBlock(containing: "b", in: exercises)?.map(\.id) == ["b", "d"])
        #expect(ActiveWorkout.supersetBlock(containing: "d", in: exercises)?.map(\.id) == ["b", "d"])
        #expect(ActiveWorkout.supersetBlock(containing: "a", in: exercises) == nil)
        // A group of one is not a superset.
        #expect(ActiveWorkout.supersetBlock(containing: "c", in: exercises) == nil)
        #expect(ActiveWorkout.supersetBlock(containing: nil, in: exercises) == nil)
        #expect(ActiveWorkout.cardExerciseIds(current: "d", in: exercises) == ["b", "d"])
        #expect(ActiveWorkout.cardExerciseIds(current: "a", in: exercises) == ["a"])
    }

    // MARK: - Rows

    @Test("Test The Rows Run In Rounds")
    func testTheRowsRunInRounds() {
        let rows = ActiveWorkout.blockRows([exercise("a"), exercise("b")])

        #expect(layout(rows) == ["A1:a-1", "B1:b-1", "A2:a-2", "B2:b-2"])
    }

    /// A member with more sets carries on alone once its partner has run out, and a circuit
    /// letters its third member C.
    @Test("Test Uneven Members And A Circuit")
    func testUnevenMembersAndACircuit() {
        let rows = ActiveWorkout.blockRows([exercise("a", working: 3), exercise("b", working: 1), exercise("c", working: 2)])

        #expect(layout(rows) == ["A1:a-1", "B1:b-1", "C1:c-1", "A2:a-2", "C2:c-2", "A3:a-3"])
    }

    /// Warm-ups are round 0: each member's together, before the first round. Logged ones fold
    /// into one line per member, as on a single exercise's card.
    @Test("Test Warm-ups Stay Grouped Above The First Round")
    func testWarmupsStayGroupedAboveTheFirstRound() {
        let rows = ActiveWorkout.blockRows([
            exercise("a", working: 1, warmups: 2, loggedWarmups: 1),
            exercise("b", working: 1, warmups: 1)
        ])

        #expect(layout(rows) == ["warmups:a", "AW:a-w2", "BW:b-w1", "A1:a-1", "B1:b-1"])
    }

    /// Both halves of a left/right pair are one set, so they sit together in their round.
    @Test("Test A Left And Right Pair Is One Entry In Its Round")
    func testALeftAndRightPairIsOneEntryInItsRound() {
        let rows = ActiveWorkout.blockRows([exercise("a", split: true), exercise("b")])

        #expect(layout(rows) == ["A1L:a-1L", "A1R:a-1R", "B1:b-1", "A2L:a-2L", "A2R:a-2R", "B2:b-2"])
    }

    @Test("Test Each Row Has Its Own Id")
    func testEachRowHasItsOwnId() {
        let rows = ActiveWorkout.blockRows([exercise("a", warmups: 1, loggedWarmups: 1), exercise("b", warmups: 1, loggedWarmups: 1)])

        #expect(Set(rows.map(\.id)).count == rows.count)
    }

    // MARK: - The current row

    /// One row is current on the card: the set the log button logs next. B1 waits as upcoming
    /// until A1 is logged, though it is B's own next set.
    @Test("Test Only The Set The Log Button Logs Next Is Current")
    func testOnlyTheSetTheLogButtonLogsNextIsCurrent() throws {
        let first = exercise("a")
        let second = exercise("b")
        let next = ActiveWorkout.nextSetId(inBlock: [first, second], current: "a")
        #expect(next == "a-1")

        let setA1 = try #require(first.sets.first)
        let setB1 = try #require(second.sets.first)
        #expect(ActiveWorkout.blockRowState(of: setA1, in: first, isNext: setA1.id == next) == .current)
        #expect(ActiveWorkout.blockRowState(of: setB1, in: second, isNext: setB1.id == next) == .upcoming)

        // With A1 logged and the card on B, B1 is next.
        var logged = first
        logged.sets[0].completedAt = start
        #expect(ActiveWorkout.nextSetId(inBlock: [logged, second], current: "b") == "b-1")
        #expect(ActiveWorkout.blockRowState(of: logged.sets[0], in: logged, isNext: false) == .done)
    }

    // MARK: - Column headings

    /// Mixed tracking modes, or one mode in two units, leave the headings off: no one heading
    /// names both members' fields.
    @Test("Test Headings Only When Every Member Shares Its Columns")
    func testHeadingsOnlyWhenEveryMemberSharesItsColumns() {
        let kilograms: (WorkoutExerciseModel) -> ExerciseUnitPreference = { ExerciseUnitPreference(exerciseModelId: $0.templateId) }
        let poundsForB: (WorkoutExerciseModel) -> ExerciseUnitPreference = {
            ExerciseUnitPreference(exerciseModelId: $0.templateId, weightUnit: $0.id == "b" ? .pounds : .kilograms)
        }

        #expect(ActiveWorkout.blockSharesColumns([exercise("a"), exercise("b")], units: kilograms))
        #expect(!ActiveWorkout.blockSharesColumns([exercise("a"), exercise("b", mode: .repsOnly)], units: kilograms))
        #expect(!ActiveWorkout.blockSharesColumns([exercise("a"), exercise("b")], units: poundsForB))
        // The weight unit is no column of a reps-only exercise.
        #expect(ActiveWorkout.blockSharesColumns([exercise("a", mode: .repsOnly), exercise("b", mode: .repsOnly)], units: poundsForB))
    }

    /// Mixed modes still interleave in rounds: the table is ordered by set, not by column.
    @Test("Test Mixed Modes Still Run In Rounds")
    func testMixedModesStillRunInRounds() {
        let rows = ActiveWorkout.blockRows([exercise("a", mode: .timeOnly), exercise("b", mode: .repsOnly)])

        #expect(layout(rows) == ["A1:a-1", "B1:b-1", "A2:a-2", "B2:b-2"])
    }

    // MARK: WP-Q

    /// A drop sits under its set in the round, before the partner: it is part of A1, and the log
    /// button takes it before walking to B1.
    @Test("Test A Drop Stays Under Its Set In The Round")
    func testADropStaysUnderItsSetInTheRound() {
        var first = exercise("a")
        first.sets = ActiveWorkout.addingSubSet(.drop, to: "a-1", in: first.sets, id: "a-1d", weightKg: 64)
        first.sets = ActiveWorkout.addingSubSet(.drop, to: "a-2", in: first.sets, id: "a-2d", weightKg: 64)

        #expect(layout(ActiveWorkout.blockRows([first, exercise("b")])) == ["A1:a-1", "A1:a-1d", "B1:b-1", "A2:a-2", "A2:a-2d", "B2:b-2"])

        first.sets[0].completedAt = start
        #expect(ActiveWorkout.nextSetId(inBlock: [first, exercise("b")], current: "a") == "a-1d")
        first.sets[1].completedAt = start
        #expect(ActiveWorkout.nextSetId(inBlock: [first, exercise("b")], current: "a") == "b-1")
    }

    /// A drop on half of a pair goes after the pair, so the round still reads 1L, 1R.
    @Test("Test A Drop On A Split Pair Follows The Pair")
    func testADropOnASplitPairFollowsThePair() {
        var first = exercise("a", working: 1, split: true)
        first.sets = ActiveWorkout.addingSubSet(.drop, to: "a-1L", in: first.sets, id: "a-1Ld", weightKg: 16)

        #expect(layout(ActiveWorkout.blockRows([first, exercise("b", working: 1)])) == ["A1L:a-1L", "A1R:a-1R", "A1L:a-1Ld", "B1:b-1"])
    }

    // MARK: - End WP-Q
}
