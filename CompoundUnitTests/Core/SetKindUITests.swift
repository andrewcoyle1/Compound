//
//  SetKindUITests.swift
//  CompoundUnitTests
//
//  Set kinds on the card, as rules: what the set-number menu offers, where a drop or mini-set
//  goes, what deleting a set takes with it, what the log button says and which of last time's
//  rows the Last column shows. `ActiveWorkout+SetKind`, `ActiveWorkout.logTitle` and the row
//  presenter's `addSubSet` and `onDeleteSetPressed`.
//

import Testing
import Foundation
@testable import Compound

@MainActor
struct SetKindUITests {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func set(
        _ id: String,
        weight: Double? = 100,
        reps: Int? = 8,
        kind: SetKind = .standard,
        parent: String? = nil,
        side: SetSide? = nil,
        warmup: Bool = false,
        logged: Bool = false
    ) -> WorkoutSetModel {
        WorkoutSetModel(
            id: id, authorId: "author-1", index: 1, reps: reps, weightKg: weight, side: side,
            kind: kind, parentSetId: parent, isWarmup: warmup, completedAt: logged ? start : nil, dateCreated: start
        )
    }

    private func exercise(_ sets: [WorkoutSetModel]) -> WorkoutExerciseModel {
        WorkoutExerciseModel(
            id: "e1", authorId: "author-1", templateId: "t1", name: "Bench Press", trackingMode: .weightReps,
            index: 1, sets: sets
        )
    }

    // MARK: - The menu

    @Test("Test The Set Type Picker Offers Every Kind But Drop")
    func testTheSetTypePickerOffersEveryKindButDrop() {
        #expect(ActiveWorkout.setTypeOptions(for: set("s1")) == [.standard, .amrap, .myo, .restPause, .cluster])
        // A template's drop set keeps its own kind among the options.
        #expect(ActiveWorkout.setTypeOptions(for: set("s1", kind: .drop)).last == .drop)
    }

    @Test("Test Kinds Are Offered On Working Sets Only")
    func testKindsAreOfferedOnWorkingSetsOnly() {
        #expect(ActiveWorkout.offersSetKinds(set("s1")))
        #expect(!ActiveWorkout.offersSetKinds(set("w1", warmup: true)))
        #expect(!ActiveWorkout.offersSetKinds(set("d1", kind: .drop, parent: "s1")))
    }

    @Test("Test A Mini-Set Is Offered Only To A Set That Rests Within Itself")
    func testAMiniSetIsOfferedOnlyToASetThatRestsWithinItself() {
        #expect(ActiveWorkout.offersMiniSet(set("s1", kind: .myo)))
        #expect(ActiveWorkout.offersMiniSet(set("s1", kind: .restPause)))
        #expect(ActiveWorkout.offersMiniSet(set("s1", kind: .cluster)))
        #expect(!ActiveWorkout.offersMiniSet(set("s1")))
        #expect(!ActiveWorkout.offersMiniSet(set("s1", kind: .amrap)))
        #expect(!ActiveWorkout.offersMiniSet(set("m1", parent: "s0")))
    }

    // MARK: - Insertion

    @Test("Test A Drop Goes Under Its Set After The Drops It Has")
    func testADropGoesUnderItsSetAfterTheDropsItHas() {
        var sets = [set("s1"), set("s2"), set("s3")]
        sets = ActiveWorkout.addingSubSet(.drop, to: "s2", in: sets, id: "d1", weightKg: 80)
        sets = ActiveWorkout.addingSubSet(.drop, to: "s2", in: sets, id: "d2", weightKg: 60)

        #expect(sets.map(\.id) == ["s1", "s2", "d1", "d2", "s3"])
        #expect(sets[2].parentSetId == "s2")
        #expect(sets[2].kind == .drop)
        #expect(sets[2].weightKg == 80)
        #expect(sets[2].reps == nil)
        #expect(sets[2].completedAt == nil)
        // Still three sets.
        #expect(sets.pairedSetCount == 3)
    }

    @Test("Test A Mini-Set Is Plain And Follows Its Set's Kind")
    func testAMiniSetIsPlainAndFollowsItsSetsKind() {
        let sets = ActiveWorkout.addingSubSet(.mini, to: "s1", in: [set("s1", kind: .myo)], id: "m1", weightKg: 100)

        #expect(sets[1].kind == .standard)
        #expect(sets[1].subSetKind == .mini)
        #expect(sets[1].weightKg == 100)
    }

    @Test("Test A Drop Is Twenty Percent Lighter On The Equipment's Grid")
    func testADropIsTwentyPercentLighterOnTheGrid() {
        let kilograms = WeightStepper.fallback(.kilograms)
        #expect(ActiveWorkout.dropWeightKg(from: 100, step: kilograms, unit: .kilograms) == 80)
        // 46 kg is no weight the 2.5 kg grid makes; 45 is.
        #expect(ActiveWorkout.dropWeightKg(from: 57.5, step: kilograms, unit: .kilograms) == 45)
        // Assistance and an empty weight are left as they are.
        #expect(ActiveWorkout.dropWeightKg(from: -30, step: kilograms, unit: .kilograms) == -30)
        #expect(ActiveWorkout.dropWeightKg(from: nil, step: kilograms, unit: .kilograms) == nil)
    }

    @Test("Test The Row Presenter Adds A Drop At The Lighter Weight")
    func testTheRowPresenterAddsADropAtTheLighterWeight() {
        let presenter = SetTrackerRowPresenter(interactor: SetTrackerRowInteractorDouble(), router: SetTrackerRowRouterDouble())
        let box = ExerciseBox(exercise([set("s1"), set("s2")]))

        presenter.addSubSet(.drop, to: "s1", exercise: box.binding)
        presenter.addSubSet(.mini, to: "s2", exercise: box.binding)

        #expect(box.exercise.sets.map(\.subSetKind) == [nil, .drop, nil, .mini])
        #expect(box.exercise.sets.map(\.weightKg) == [100, 80, 100, 100])
    }

    // MARK: - Deleting

    private func removed(_ setId: String, in sets: [WorkoutSetModel]) -> String {
        let counts = ActiveWorkout.subSetsRemovedByDeleting(setId, in: sets)
        return "\(counts.drops) drops, \(counts.minis) minis"
    }

    @Test("Test Deleting A Set Takes Its Drops With It")
    func testDeletingASetTakesItsDropsWithIt() {
        let sets = [set("s1"), set("d1", kind: .drop, parent: "s1"), set("d2", kind: .drop, parent: "s1"), set("s2")]

        #expect(Set(ActiveWorkout.idsRemovedByDeleting("s1", in: sets)) == ["s1", "d1", "d2"])
        // A drop on its own goes alone.
        #expect(ActiveWorkout.idsRemovedByDeleting("d2", in: sets) == ["d2"])
        #expect(removed("s1", in: sets) == "2 drops, 0 minis")
        #expect(removed("s2", in: sets) == "0 drops, 0 minis")
    }

    @Test("Test Deleting Half Of A Pair Takes Both Halves' Drops")
    func testDeletingHalfOfAPairTakesBothHalvesDrops() {
        let sets = [
            set("s1L", side: .left), set("s1R", side: .right),
            set("d1L", kind: .drop, parent: "s1L", side: .left), set("d1R", kind: .drop, parent: "s1R", side: .right)
        ]

        #expect(Set(ActiveWorkout.idsRemovedByDeleting("s1R", in: sets)) == ["s1L", "s1R", "d1L", "d1R"])
        // A left and a right drop are one drop.
        #expect(removed("s1L", in: sets) == "1 drops, 0 minis")
    }

    @Test("Test Deleting A Set With Drops Asks First")
    func testDeletingASetWithDropsAsksFirst() {
        let router = SetTrackerRowRouterDouble()
        let presenter = SetTrackerRowPresenter(interactor: SetTrackerRowInteractorDouble(), router: router)
        let box = ExerciseBox(exercise([set("s1"), set("d1", kind: .drop, parent: "s1"), set("d2", kind: .drop, parent: "s1"), set("s2")]))

        presenter.onDeleteSetPressed(setId: "s1", setName: "Set 1", exercise: box.binding)
        #expect(router.confirmations.map(\.title) == ["Delete Set 1?"])
        #expect(router.confirmations.first?.subtitle == "This also deletes its 2 drop sets.")
        #expect(box.exercise.sets.count == 4)

        // Confirmed, all three go; a set with none goes without asking.
        presenter.deleteSet(setId: "s1", exercise: box.binding)
        presenter.onDeleteSetPressed(setId: "s2", setName: "Set 2", exercise: box.binding)
        #expect(box.exercise.sets.isEmpty)
        #expect(router.confirmations.count == 1)
    }

    // MARK: - Log titles

    @Test("Test The Log Button Names The Set's Kind")
    func testTheLogButtonNamesTheSetsKind() {
        let sets = [
            set("s1", logged: true),
            set("d1", weight: 80, kind: .drop, parent: "s1"),
            set("s2", reps: nil, kind: .amrap),
            set("s3", kind: .myo, logged: true),
            set("m1", reps: 4, parent: "s3", logged: true),
            set("m2", reps: 4, parent: "s3")
        ]
        let current = exercise(sets)
        func title(_ index: Int) -> String {
            ActiveWorkout.logTitle(for: sets[index], in: current, unit: .kilograms, distanceUnit: .meters)
        }

        #expect(title(1) == "Log drop set · 80 kg × 8")
        #expect(title(2) == "Log AMRAP set · 100 kg")
        #expect(title(5) == "Log mini-set 2 · 100 kg × 4")
        // A myo set is still numbered.
        #expect(title(3) == "Log set 3 · 100 kg × 8")
    }

    @Test("Test A Drop Becomes Current Once Its Set Is Logged")
    func testADropBecomesCurrentOnceItsSetIsLogged() {
        let current = exercise([set("s1", logged: true), set("d1", kind: .drop, parent: "s1"), set("s2")])

        #expect(ActiveWorkout.rowState(of: current.sets[1], in: current) == .current)
        #expect(ActiveWorkout.rowState(of: current.sets[2], in: current) == .upcoming)
        #expect(current.workingSetNumber(for: current.sets[2]) == 2)
    }

    // MARK: - Last

    @Test("Test A Drop's Last Is Last Time's Drop, Never Its Set")
    func testADropsLastIsLastTimesDrop() {
        let last = exercise([
            set("p1", weight: 100, logged: true),
            set("pd1", weight: 80, kind: .drop, parent: "p1", logged: true),
            set("pd2", weight: 60, kind: .drop, parent: "p1", logged: true),
            set("p2", weight: 102.5, logged: true)
        ])
        let today = exercise([
            set("s1"), set("d1", kind: .drop, parent: "s1"), set("d2", kind: .drop, parent: "s1"), set("d3", kind: .drop, parent: "s1"),
            set("s2"), set("d4", kind: .drop, parent: "s2")
        ])
        func lastId(_ index: Int) -> String? {
            ActiveWorkout.lastSet(for: today.sets[index], in: today, last: last)?.id
        }

        #expect(lastId(0) == "p1")
        #expect(lastId(1) == "pd1")
        #expect(lastId(2) == "pd2")
        // A third drop had none last time, and set 2 had no drop.
        #expect(lastId(3) == nil)
        #expect(lastId(4) == "p2")
        #expect(lastId(5) == nil)
    }

    @Test("Test A Mini-Set's Last Is Matched By Kind")
    func testAMiniSetsLastIsMatchedByKind() {
        let last = exercise([
            set("p1", kind: .myo, logged: true),
            set("pd1", weight: 80, kind: .drop, parent: "p1", logged: true),
            set("pm1", reps: 5, parent: "p1", logged: true)
        ])
        let today = exercise([set("s1", kind: .myo), set("m1", parent: "s1")])

        #expect(ActiveWorkout.lastSet(for: today.sets[1], in: today, last: last)?.id == "pm1")
    }

    @Test("Test The Row Is Named After Its Set")
    func testTheRowIsNamedAfterItsSet() {
        let sets = [set("s1"), set("d1", kind: .drop, parent: "s1"), set("m1", parent: "s1"), set("d2", kind: .drop, parent: "s1")]

        #expect(ActiveWorkout.subSetName(of: sets[3], in: sets) == "drop set 2")
        #expect(ActiveWorkout.subSetName(of: sets[2], in: sets) == "mini-set 1")
        #expect(ActiveWorkout.subSetName(of: sets[0], in: sets) == nil)
    }
}
