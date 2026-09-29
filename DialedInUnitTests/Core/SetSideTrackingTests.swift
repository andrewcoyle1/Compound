//
//  SetSideTrackingTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

/// Tracking an exercise worked one limb at a time.
///
/// The two screens that touch a live set — the list and the row — both have to treat a left and
/// the right after it as one set: added together, deleted together, and rested between rather than
/// after. Getting this wrong leaves a user with a left arm and no right to follow it, or a rest
/// screen sitting between their two arms for the full two minutes.
@MainActor
struct SetSideTrackingTests {

    // MARK: - Doubles

    private final class ListInteractor: SpyGlobalInteractor, SetTrackerInteractor {
        var userId: String? = "user-1"
        var currentUser: UserModel? = UserModel(userId: "user-1")
        var systemExercises: [ExerciseModel] = []
        var userExercises: [ExerciseModel] = []
        var allExercises: [ExerciseModel] = []
        var favouriteGymProfile: GymProfileModel?
        var workoutGymProfile: GymProfileModel?
        var workoutSettings: WorkoutSettings = WorkoutSettings(authorId: "user-1")

        func getPreference(templateId: String) -> ExerciseUnitPreference {
            ExerciseUnitPreference(exerciseModelId: templateId)
        }

        func setWeightUnit(_ unit: ExerciseWeightUnit, for templateId: String) { }
        func setDistanceUnit(_ unit: ExerciseDistanceUnit, for templateId: String) { }
    }

    private final class RowInteractor: SpyGlobalInteractor, SetTrackerRowInteractor {
        var workoutSettings: WorkoutSettings = WorkoutSettings(authorId: "user-1")
        var favouriteGymProfile: GymProfileModel?
        var allExercises: [ExerciseModel] = []
        var restOverrides: [String: Int] = [:]

        func getPreference(templateId: String) -> ExerciseUnitPreference {
            ExerciseUnitPreference(exerciseModelId: templateId)
        }

        func exerciseRestOverride(for exerciseId: String) -> Int? {
            restOverrides[exerciseId]
        }
    }

    /// The alerts this screen raises go through `GlobalRouter` extensions, which dispatch
    /// statically and never reach a double — so nothing here records them.
    private final class ListRouter: SetTrackerRouter {
        let router: AnyRouter = TestRouting.anyRouter

        func showWorkoutExerciseEquipmentSheetView(delegate: WorkoutExerciseEquipmentSheetDelegate) { }
        func showWarmupSetInfoModal(primaryButtonAction: @escaping () -> Void) { }
        func showRestModal(
            primaryButtonAction: @escaping () -> Void,
            secondaryButtonAction: @escaping () -> Void,
            minutesSelection: Binding<Int>,
            secondsSelection: Binding<Int>
        ) { }
        func showWarmupSetsView(delegate: WarmupSetsDelegate) { }
        func showExerciseSettingsView(delegate: ExerciseSettingsDelegate) { }
        func showSetTargetView(delegate: SetTargetDelegate) { }
        func showSwapExercisePickerView(onSelect: @escaping (ExerciseModel) -> Void) { }
    }

    private final class RowRouter: SetTrackerRowRouter {
        let router: AnyRouter = TestRouting.anyRouter

        func showWarmupSetInfoModal(primaryButtonAction: @escaping () -> Void) { }
        func showRestModal(
            primaryButtonAction: @escaping () -> Void,
            secondaryButtonAction: @escaping () -> Void,
            minutesSelection: Binding<Int>,
            secondsSelection: Binding<Int>
        ) { }
    }

    /// Holds the exercise the presenters edit through a `Binding`. Main-actor isolated so it is
    /// `Sendable`, which `Binding`'s `@Sendable` accessors require.
    @MainActor
    private final class MutableExercise {
        var value: WorkoutExerciseModel

        init(_ value: WorkoutExerciseModel) {
            self.value = value
        }

        var binding: Binding<WorkoutExerciseModel> {
            Binding(
                get: { MainActor.assumeIsolated { self.value } },
                set: { newValue in MainActor.assumeIsolated { self.value = newValue } }
            )
        }
    }

    private func makeListPresenter() -> (SetTrackerPresenter, ListInteractor) {
        let interactor = ListInteractor()
        return (SetTrackerPresenter(interactor: interactor, router: ListRouter()), interactor)
    }

    private func makeRowPresenter() -> (SetTrackerRowPresenter, RowInteractor) {
        let interactor = RowInteractor()
        return (SetTrackerRowPresenter(interactor: interactor, router: RowRouter()), interactor)
    }

    private func set(
        id: String,
        index: Int,
        side: SetSide? = nil,
        reps: Int? = 10,
        weightKg: Double? = 20,
        isWarmup: Bool = false
    ) -> WorkoutSetModel {
        WorkoutSetModel(
            id: id,
            authorId: "user-1",
            index: index,
            reps: reps,
            weightKg: weightKg,
            side: side,
            isWarmup: isWarmup,
            dateCreated: Date()
        )
    }

    private func exercise(templateId: String = "template-1", sets: [WorkoutSetModel]) -> WorkoutExerciseModel {
        WorkoutExerciseModel(
            id: "exercise-1",
            authorId: "user-1",
            templateId: templateId,
            name: "Single Arm Row",
            trackingMode: .weightReps,
            index: 1,
            sets: sets
        )
    }

    private var onePair: [WorkoutSetModel] {
        [set(id: "s1", index: 1, side: .left), set(id: "s2", index: 2, side: .right)]
    }

    // MARK: - Adding in pairs

    /// Tapping "+" on a single-arm row adds one more set, which is a left and a right — the user
    /// is never handed a left arm with no right to follow it.
    @Test("Test Adding A Set To A Per-Side Exercise Adds Both Limbs")
    func testAddingASetToAPerSideExerciseAddsBothLimbs() {
        let (presenter, _) = makeListPresenter()
        let box = MutableExercise(exercise(sets: onePair))

        presenter.addSet(exercise: box.binding)

        #expect(box.value.sets.map(\.side) == [.left, .right, .left, .right])
        #expect(box.value.sets.map(\.index) == [1, 2, 3, 4])
        #expect(box.value.workingSetCount == 2)
    }

    /// A new left set copies the left arm's last figures rather than whatever row happened to be
    /// at the bottom — the two arms are rarely equally strong.
    @Test("Test A New Pair Copies Each Side's Own Figures")
    func testANewPairCopiesEachSidesOwnFigures() {
        let (presenter, _) = makeListPresenter()
        let box = MutableExercise(exercise(sets: [
            set(id: "s1", index: 1, side: .left, reps: 10, weightKg: 20),
            set(id: "s2", index: 2, side: .right, reps: 8, weightKg: 22.5)
        ]))

        presenter.addSet(exercise: box.binding)

        #expect(box.value.sets[2].weightKg == 20)
        #expect(box.value.sets[2].reps == 10)
        #expect(box.value.sets[3].weightKg == 22.5)
        #expect(box.value.sets[3].reps == 8)
    }

    /// Indices stay unique and contiguous across the pair. Sides are told apart by `side`, never by
    /// index — duplicate indices are what last session's figures are matched on.
    @Test("Test A Added Pair Takes Two Fresh Indices")
    func testAAddedPairTakesTwoFreshIndices() {
        let (presenter, _) = makeListPresenter()
        let box = MutableExercise(exercise(sets: onePair))

        presenter.deleteSet(setId: "s1", exercise: box.binding)
        presenter.addSet(exercise: box.binding)
        presenter.addSet(exercise: box.binding)

        let indices = box.value.sets.map(\.index)
        #expect(Set(indices).count == indices.count)
    }

    /// Nothing changes for the exercises that are not worked a side at a time, which is nearly all
    /// of them.
    @Test("Test Adding To A Two-Sided Exercise Still Adds One Set")
    func testAddingToATwoSidedExerciseStillAddsOneSet() {
        let (presenter, _) = makeListPresenter()
        let box = MutableExercise(exercise(sets: [set(id: "s1", index: 1)]))

        presenter.addSet(exercise: box.binding)

        #expect(box.value.sets.count == 2)
        #expect(box.value.sets.allSatisfy { $0.side == nil })
    }

    // MARK: - Deleting in pairs

    /// Swiping either half away removes the set. A surviving half would number as a set of its own
    /// and claim the user had done work on one arm they never did on the other.
    @Test("Test Deleting Either Half Removes The Whole Set")
    func testDeletingEitherHalfRemovesTheWholeSet() {
        let (listPresenter, _) = makeListPresenter()
        let (rowPresenter, _) = makeRowPresenter()
        let fromList = MutableExercise(exercise(sets: onePair + [
            set(id: "s3", index: 3, side: .left), set(id: "s4", index: 4, side: .right)
        ]))
        let fromRow = MutableExercise(exercise(sets: onePair + [
            set(id: "s3", index: 3, side: .left), set(id: "s4", index: 4, side: .right)
        ]))

        listPresenter.deleteSet(setId: "s1", exercise: fromList.binding)
        rowPresenter.deleteSet(setId: "s4", exercise: fromRow.binding)

        #expect(fromList.value.sets.map(\.id) == ["s3", "s4"])
        #expect(fromRow.value.sets.map(\.id) == ["s1", "s2"])
    }

    /// Warm-ups stay single-sided, so deleting one takes only that row with it.
    @Test("Test Deleting A Warm-Up Takes Nothing Else")
    func testDeletingAWarmUpTakesNothingElse() {
        let (presenter, _) = makeListPresenter()
        let box = MutableExercise(exercise(sets: [
            set(id: "w1", index: 1, isWarmup: true)
        ] + onePair))

        presenter.deleteSet(setId: "w1", exercise: box.binding)

        #expect(box.value.sets.map(\.id) == ["s1", "s2"])
    }

    // MARK: - Last session's figures

    /// A left set must not inherit the right arm's history: the user would chase a number the
    /// other arm set and wonder why it felt heavy.
    @Test("Test The Previous Lookup Keeps The Sides Apart")
    func testThePreviousLookupKeepsTheSidesApart() {
        let (presenter, _) = makeListPresenter()
        let previous = exercise(sets: [
            set(id: "p1", index: 1, side: .left, weightKg: 20),
            set(id: "p2", index: 2, side: .right, weightKg: 22.5)
        ])
        presenter.previousExercises = [previous.templateId: previous]

        let lookup = presenter.buildPreviousLookup(for: exercise(sets: onePair))

        #expect(lookup.match(for: set(id: "s1", index: 1, side: .left))?.weightKg == 20)
        #expect(lookup.match(for: set(id: "s2", index: 2, side: .right))?.weightKg == 22.5)
        // The left side of set two has no history yet, and the right arm's is not its to borrow.
        #expect(lookup.match(for: set(id: "s3", index: 2, side: .left)) == nil)
    }

    // MARK: - The rest between limbs

    /// The point of the whole feature. Swapping hands is not a rest between sets, so by default the
    /// gap between the two limbs of one set is a fraction of the real one.
    @Test("Test A Left Set Rests At The Side Scaling")
    func testALeftSetRestsAtTheSideScaling() {
        let (presenter, interactor) = makeRowPresenter()
        interactor.workoutSettings.restBetweenSideSets = true
        interactor.workoutSettings.sideSetRestScaling = 0.5
        let left = set(id: "s1", index: 1, side: .left)

        let rest = presenter.restAfterCompleting(left, in: exercise(sets: [left, set(id: "s2", index: 2, side: .right)]))

        // 90 at the default rest, halved.
        #expect(rest == 45)
    }

    /// Off by default: most people put the dumbbell straight into the other hand, and a timer
    /// appearing between their arms is exactly the interruption the setting exists to prevent.
    @Test("Test No Rest Runs Between Limbs When Turned Off")
    func testNoRestRunsBetweenLimbsWhenTurnedOff() {
        let (presenter, interactor) = makeRowPresenter()
        interactor.workoutSettings.restBetweenSideSets = false
        let left = set(id: "s1", index: 1, side: .left)

        let rest = presenter.restAfterCompleting(left, in: exercise(sets: [left, set(id: "s2", index: 2, side: .right)]))

        #expect(rest == nil)
    }

    /// The right side finishes the set, so what follows it is the ordinary rest between sets — the
    /// one that actually needs to be long.
    @Test("Test The Right Side Rests Like Any Other Set")
    func testTheRightSideRestsLikeAnyOtherSet() {
        let (presenter, interactor) = makeRowPresenter()
        interactor.workoutSettings.restBetweenSideSets = true
        let right = set(id: "s2", index: 2, side: .right)
        let sets = [set(id: "s1", index: 1, side: .left), right,
                    set(id: "s3", index: 3, side: .left), set(id: "s4", index: 4, side: .right)]

        #expect(presenter.restAfterCompleting(right, in: exercise(sets: sets)) == 90)
    }

    /// A left set is never the last working set, so the side check has to come first — otherwise
    /// the last pair would take the walk-to-the-next-exercise rest in the middle of itself.
    @Test("Test The Last Pairs Left Side Still Takes The Side Rest")
    func testTheLastPairsLeftSideStillTakesTheSideRest() {
        let (presenter, interactor) = makeRowPresenter()
        interactor.workoutSettings.restBetweenSideSets = true
        interactor.workoutSettings.betweenExercisesRestScaling = 0.25
        let left = set(id: "s1", index: 1, side: .left)
        let right = set(id: "s2", index: 2, side: .right)

        #expect(presenter.restAfterCompleting(left, in: exercise(sets: [left, right])) == 45)
        // And the right side, which really is last, still walks to the next exercise.
        #expect(presenter.restAfterCompleting(right, in: exercise(sets: [left, right])) == 23)
    }

    /// A rest typed on this set is what the user asked for and wins over every scaling, sides
    /// included.
    @Test("Test A Hand-Set Rest Beats The Side Scaling")
    func testAHandSetRestBeatsTheSideScaling() {
        let (presenter, interactor) = makeRowPresenter()
        interactor.workoutSettings.restBetweenSideSets = true
        presenter.updateRestBefore(setId: "s1", seconds: 30)
        let left = set(id: "s1", index: 1, side: .left)

        let rest = presenter.restAfterCompleting(left, in: exercise(sets: [left, set(id: "s2", index: 2, side: .right)]))

        #expect(rest == 30)
    }

    /// An orphaned left set — one whose right partner was removed by an older build — is not half
    /// of anything, so it rests as the ordinary last set it now is.
    @Test("Test A Left Set With No Partner Rests As A Whole Set")
    func testALeftSetWithNoPartnerRestsAsAWholeSet() {
        let (presenter, interactor) = makeRowPresenter()
        interactor.workoutSettings.restBetweenSideSets = true
        interactor.workoutSettings.betweenExercisesRestScaling = 0.5
        let lonely = set(id: "s1", index: 1, side: .left)

        #expect(presenter.restAfterCompleting(lonely, in: exercise(sets: [lonely])) == 45)
    }
}
