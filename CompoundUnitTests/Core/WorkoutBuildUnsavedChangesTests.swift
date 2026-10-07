//
//  WorkoutBuildUnsavedChangesTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

/// Holds exercises by reference so the presenters' `Binding` APIs can be driven and read back.
@MainActor
private final class UnsavedExerciseBox {
    var value: [WorkoutTemplateExercise]

    init(_ value: [WorkoutTemplateExercise] = []) {
        self.value = value
    }

    var binding: Binding<[WorkoutTemplateExercise]> {
        Binding(
            get: { MainActor.assumeIsolated { self.value } },
            set: { newValue in MainActor.assumeIsolated { self.value = newValue } }
        )
    }

    /// The first exercise, as the set-target sheet receives it.
    var first: Binding<WorkoutTemplateExercise> {
        Binding(
            get: { MainActor.assumeIsolated { self.value[0] } },
            set: { newValue in MainActor.assumeIsolated { self.value[0] = newValue } }
        )
    }
}

@MainActor
private func unsavedExercise(_ id: String) -> WorkoutTemplateExercise {
    WorkoutTemplateExercise(
        exercise: ExerciseModel(
            id: id,
            authorId: "author-1",
            name: id,
            trackableMetrics: [.weight, .reps],
            type: .compoundUpper,
            laterality: .bilateral,
            muscleGroups: [.chest: .primary],
            isBodyweight: false,
            rangeOfMotion: 4,
            stability: 5,
            bodyWeightContribution: 0,
            alternateNames: []
        ),
        setRestTimers: false
    )
}

/// Records the discard prompt. `showConfirmationDialog` is a `GlobalRouter` requirement, so the
/// double's version is what `showDiscardChangesDialog` reaches.
@MainActor
private final class DialogRouter: SetTargetRouter, ExercisesPickerRouter {
    let router: AnyRouter = TestRouting.anyRouter
    private(set) var dialogTitles: [String] = []

    func showConfirmationDialog(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) {
        dialogTitles.append(title)
    }

    func showSetPlanDetailView(delegate: SetPlanDetailDelegate) { }
}

private final class SetTargetSpyInteractor: SpyGlobalInteractor, SetTargetInteractor {
    var workoutSettings = WorkoutSettings(authorId: "user-1")
}
private final class PickerSpyInteractor: SpyGlobalInteractor, ExercisesPickerInteractor { }
private final class WrapperSpyInteractor: SpyGlobalInteractor, DefineWorkoutWrapperInteractor, DefineWorkoutInteractor {
    var currentUser: UserModel? = UserModel(userId: "user-1")
    func saveWorkoutTemplate(workoutTemplate: WorkoutTemplateModel, image: PlatformImage?) async throws { }
}
private final class WrapperRouter: DefineWorkoutWrapperRouter, DefineWorkoutRouter {
    let router: AnyRouter = TestRouting.anyRouter
    func showExercisesPickerView(delegate: ExercisesPickerDelegate) { }
    func showSetTargetView(delegate: SetTargetDelegate) { }
}

/// Swiping a sheet down, closing it or backing out used to drop the user's edits without a word.
@MainActor
struct WorkoutBuildUnsavedChangesTests {

    // MARK: - Set targets

    @Test("Test Closing Set Targets After An Edit Asks First")
    func testClosingSetTargetsAfterAnEditAsksFirst() {
        let box = UnsavedExerciseBox([unsavedExercise("bench")])
        let router = DialogRouter()
        let presenter = SetTargetPresenter(interactor: SetTargetSpyInteractor(), router: router, delegate: SetTargetDelegate(exercise: box.first))

        #expect(!presenter.hasUnsavedChanges)
        presenter.onClosePressed()
        #expect(router.dialogTitles.isEmpty)

        presenter.onAddSetPressed()
        #expect(presenter.hasUnsavedChanges)
        presenter.onClosePressed()
        #expect(router.dialogTitles == ["Discard Changes?"])
        #expect(box.value[0].setTargets.count == 1)
    }

    /// A minimum above its maximum used to save as "12–8 reps".
    @Test("Test A Minimum Above The Maximum Is Swapped On Save")
    func testAMinimumAboveTheMaximumIsSwappedOnSave() {
        let box = UnsavedExerciseBox([unsavedExercise("bench")])
        let presenter = SetTargetPresenter(interactor: SetTargetSpyInteractor(), router: DialogRouter(), delegate: SetTargetDelegate(exercise: box.first))
        presenter.workingExercise.setTargets[0].minReps = 12
        presenter.workingExercise.setTargets[0].maxReps = 8

        presenter.onSavePressed()

        #expect(box.value[0].setTargets[0].minReps == 8)
        #expect(box.value[0].setTargets[0].maxReps == 12)
    }

    @Test("Test Deleting A Set Renumbers The Rest")
    func testDeletingASetRenumbersTheRest() {
        let box = UnsavedExerciseBox([unsavedExercise("bench")])
        let presenter = SetTargetPresenter(interactor: SetTargetSpyInteractor(), router: DialogRouter(), delegate: SetTargetDelegate(exercise: box.first))
        presenter.onAddSetPressed()
        presenter.onAddSetPressed()

        presenter.onDeleteSetPressed(presenter.workingExercise.setTargets[0])

        let numbers = presenter.workingExercise.setTargets.map(\.setNumber)
        #expect(numbers == [1, 2])
    }

    // MARK: - The exercise picker

    @Test("Test Closing The Picker With Ticked Exercises Asks First")
    func testClosingThePickerWithTickedExercisesAsksFirst() {
        let router = DialogRouter()
        let presenter = ExercisesPickerPresenter(
            interactor: PickerSpyInteractor(),
            router: router,
            delegate: ExercisesPickerDelegate(addedExercises: UnsavedExerciseBox().binding)
        )

        presenter.onDismissPressed()
        #expect(router.dialogTitles.isEmpty)

        presenter.onExercisePressed(exercise: unsavedExercise("bench").exercise)
        presenter.onDismissPressed()
        #expect(router.dialogTitles == ["Discard Changes?"])
    }

    /// Exercises already in the workout show ticked and cannot be unticked or picked again here.
    @Test("Test Exercises Already In The Workout Are Ticked And Locked")
    func testExercisesAlreadyInTheWorkoutAreTickedAndLocked() {
        let existing = unsavedExercise("squat")
        let presenter = ExercisesPickerPresenter(
            interactor: PickerSpyInteractor(),
            router: DialogRouter(),
            delegate: ExercisesPickerDelegate(addedExercises: UnsavedExerciseBox([existing]).binding)
        )

        presenter.onExercisePressed(exercise: existing.exercise)

        #expect(presenter.workingExercises.isEmpty)
        #expect(!presenter.canSave)
        #expect(presenter.selectedExercises.map(\.id) == ["squat"])
    }

    // MARK: - Backing out of the builder

    /// Backing out to the name step and coming forward again used to start the exercise list over.
    @Test("Test The Exercise List Survives Going Back")
    func testTheExerciseListSurvivesGoingBack() {
        let draft = UnsavedExerciseBox()
        let first = DefineWorkoutWrapperPresenter(interactor: WrapperSpyInteractor(), router: WrapperRouter(), draft: draft.binding)
        first.exercises = [unsavedExercise("bench"), unsavedExercise("row")]

        let second = DefineWorkoutWrapperPresenter(interactor: WrapperSpyInteractor(), router: WrapperRouter(), draft: draft.binding)

        #expect(second.exercises.map(\.exercise.id) == ["bench", "row"])
    }

    /// Exercises used to stay in the order they were picked in.
    @Test("Test Moving An Exercise Reorders The Workout")
    func testMovingAnExerciseReordersTheWorkout() {
        let box = UnsavedExerciseBox([unsavedExercise("bench"), unsavedExercise("row"), unsavedExercise("squat")])
        let presenter = DefineWorkoutPresenter(interactor: WrapperSpyInteractor(), router: WrapperRouter(), exercises: box.binding)

        presenter.moveExercises(from: IndexSet(integer: 2), to: 0)

        #expect(box.value.map(\.exercise.id) == ["squat", "bench", "row"])
    }
}
