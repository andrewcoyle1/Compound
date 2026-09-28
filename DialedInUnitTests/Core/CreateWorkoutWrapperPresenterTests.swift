//
//  CreateWorkoutWrapperPresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

/// Holds a list of template exercises so the presenters' `Binding`-taking APIs can be driven
/// without a view and read back. Main-actor isolated so it is `Sendable`, as `Binding` requires.
@MainActor
private final class CreateWorkoutFlowExerciseBox {
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
}

/// An exercise targeting whichever muscles the test cares about.
@MainActor
private func flowExercise(
    id: String = UUID().uuidString,
    name: String = "Bench Press",
    muscles: [Muscles: MuscleTargetType] = [.chest: .primary]
) -> ExerciseModel {
    ExerciseModel(
        id: id,
        authorId: "author-1",
        name: name,
        trackableMetrics: [.weight, .reps],
        type: .compoundUpper,
        laterality: .bilateral,
        muscleGroups: muscles,
        isBodyweight: false,
        rangeOfMotion: 4,
        stability: 5,
        bodyWeightContribution: 0,
        alternateNames: []
    )
}

/// A template exercise whose sets are numbered the way the set-target screen numbers them.
@MainActor
private func flowTemplateExercise(
    id: String = UUID().uuidString,
    exercise: ExerciseModel,
    setCount: Int = 1
) -> WorkoutTemplateExercise {
    WorkoutTemplateExercise(
        id: id,
        exercise: exercise,
        setTargets: (1...max(setCount, 1)).prefix(setCount).map { SetTarget(setNumber: $0) },
        setRestTimers: false
    )
}

// MARK: - Step 5: turning it into a workout

/// The wrapper around the define screen, which owns the Save (or Start Workout) button and turns
/// everything the wizard gathered into a `WorkoutTemplateModel`. It is the last chance to lose
/// what the user chose: the name from step two, the gym from step three and the exercises from
/// step four all have to reach the saved template.
@MainActor
struct WorkoutBuildWrapperPresenterTests {

    private final class Interactor: SpyGlobalInteractor, DefineWorkoutWrapperInteractor {
        var currentUser: UserModel? = UserModel(userId: "user-1")
        var saveError: Error?
        var saveDelay: Duration = .zero
        private(set) var savedTemplates: [WorkoutTemplateModel] = []

        func saveWorkoutTemplate(workoutTemplate: WorkoutTemplateModel, image: PlatformImage?) async throws {
            try? await Task.sleep(for: saveDelay)
            if let saveError {
                throw saveError
            }
            savedTemplates.append(workoutTemplate)
        }
    }

    /// `DefineWorkoutWrapperRouter` adds no requirements: the confirm path uses `showSimpleAlert`
    /// and `dismissEnvironment`, `GlobalRouter` extension methods that dispatch statically and
    /// never reach this double. The tests assert what was saved instead.
    private final class Router: DefineWorkoutWrapperRouter {
        let router: AnyRouter = TestRouting.anyRouter
    }

    private struct Screen {
        let presenter: DefineWorkoutWrapperPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen() -> Screen {
        let interactor = Interactor()
        let router = Router()
        return Screen(
            presenter: DefineWorkoutWrapperPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    private func delegate(
        name: String = "Push Day",
        gymId: String = "gym-1",
        workoutTemplate: WorkoutTemplateModel? = nil
    ) -> DefineWorkoutWrapperDelegate {
        DefineWorkoutWrapperDelegate(
            name: name,
            gymProfile: GymProfileModel(id: gymId, authorId: "user-1", name: "Home Gym"),
            workoutTemplate: workoutTemplate
        )
    }

    // MARK: Saving from the library flow

    @Test("Test The Workout Is Saved Under The Name The User Typed")
    func testTheWorkoutIsSavedUnderTheNameTheUserTyped() async {
        let screen = makeScreen()
        screen.presenter.exercises = [flowTemplateExercise(exercise: flowExercise())]

        screen.presenter.onConfirmPressed(delegate: delegate(name: "Leg Day"))

        #expect(await TestManagers.eventually { !screen.interactor.savedTemplates.isEmpty })
        #expect(screen.interactor.savedTemplates.first?.name == "Leg Day")
        #expect(screen.interactor.savedTemplates.first?.authorId == "user-1")
        #expect(await TestManagers.eventually { !screen.interactor.playedHaptics.isEmpty })
        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["success"])
    }

    /// The gym is chosen in its own step of the wizard and is what the tracker later uses to work
    /// out which equipment is to hand, so a template saved without it sends the user into a
    /// workout that does not know where it is being done.
    @Test("Test The Chosen Gym Is Saved With The Workout")
    func testTheChosenGymIsSavedWithTheWorkout() async {
        let screen = makeScreen()
        screen.presenter.exercises = [flowTemplateExercise(exercise: flowExercise())]

        screen.presenter.onConfirmPressed(delegate: delegate(gymId: "gym-7"))

        #expect(await TestManagers.eventually { !screen.interactor.savedTemplates.isEmpty })
        #expect(screen.interactor.savedTemplates.first?.gymProfileId == "gym-7")
    }

    @Test("Test The Exercises Assembled On The Screen Are Saved")
    func testTheExercisesAssembledOnTheScreenAreSaved() async {
        let screen = makeScreen()
        screen.presenter.exercises = [
            flowTemplateExercise(exercise: flowExercise(name: "Squat"), setCount: 3),
            flowTemplateExercise(exercise: flowExercise(name: "Leg Press"), setCount: 2)
        ]

        screen.presenter.onConfirmPressed(delegate: delegate())

        #expect(await TestManagers.eventually { !screen.interactor.savedTemplates.isEmpty })
        let saved = screen.interactor.savedTemplates.first
        #expect(saved?.exercises.map(\.exercise.name) == ["Squat", "Leg Press"])
        #expect(saved?.exercises.first?.setTargets.map(\.setNumber) == [1, 2, 3])
    }

    /// Without a signed-in user there is no author to save the workout under, so the screen does
    /// nothing rather than writing an ownerless template.
    @Test("Test Nothing Is Saved Without A Signed In User")
    func testNothingIsSavedWithoutASignedInUser() async {
        let screen = makeScreen()
        screen.presenter.exercises = [flowTemplateExercise(exercise: flowExercise())]
        screen.interactor.currentUser = nil

        screen.presenter.onConfirmPressed(delegate: delegate())

        let saved = await TestManagers.eventually(timeout: .milliseconds(400)) { !screen.interactor.savedTemplates.isEmpty }
        #expect(!saved)
        #expect(await TestManagers.eventually { !screen.interactor.playedHaptics.isEmpty })
        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["error"])
    }

    /// A save that fails raises an alert rather than crashing or pretending to have worked. The
    /// alert is a `GlobalRouter` extension and cannot be observed, so what is checked is that the
    /// failure is contained and nothing is recorded as saved.
    @Test("Test A Failed Save Is Survived")
    func testAFailedSaveIsSurvived() async {
        let screen = makeScreen()
        screen.presenter.exercises = [flowTemplateExercise(exercise: flowExercise())]
        screen.interactor.saveError = URLError(.notConnectedToInternet)

        screen.presenter.onConfirmPressed(delegate: delegate())

        let saved = await TestManagers.eventually(timeout: .milliseconds(400)) { !screen.interactor.savedTemplates.isEmpty }
        #expect(!saved)
        #expect(await TestManagers.eventually { screen.interactor.playedHaptics.map { "\($0)" } == ["error"] })
        #expect(await TestManagers.eventually { !screen.interactor.playedHaptics.isEmpty })
        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["error"])
    }

    /// An empty template starts a workout with nothing in it, so Save stays off until there is one.
    @Test("Test A Workout With No Exercises Cannot Be Saved")
    func testAWorkoutWithNoExercisesCannotBeSaved() async {
        let screen = makeScreen()

        #expect(!screen.presenter.canSave)
        screen.presenter.onConfirmPressed(delegate: delegate())

        let saved = await TestManagers.eventually(timeout: .milliseconds(200)) { !screen.interactor.savedTemplates.isEmpty }
        #expect(!saved)
    }

    /// Editing kept the name and gym but built a brand-new model, so "Edit" saved a duplicate and
    /// left the original in the library.
    @Test("Test Editing Saves Under The Original Id")
    func testEditingSavesUnderTheOriginalId() async {
        let screen = makeScreen()
        let created = Date(timeIntervalSince1970: 1_000)
        let original = WorkoutTemplateModel(
            id: "wt-1", authorId: "user-1", name: "Old Name", description: "keep", gymProfileId: "gym-1", dateCreated: created
        )
        screen.presenter.exercises = [flowTemplateExercise(exercise: flowExercise())]

        screen.presenter.onConfirmPressed(delegate: delegate(name: "New Name", workoutTemplate: original))

        #expect(await TestManagers.eventually { !screen.interactor.savedTemplates.isEmpty })
        let saved = screen.interactor.savedTemplates.first
        #expect(saved?.id == "wt-1")
        #expect(saved?.name == "New Name")
        #expect(saved?.description == "keep")
        #expect(saved?.dateCreated == created)
    }

    /// The exercises a template already has are the starting point when editing it.
    @Test("Test Editing Starts From The Existing Exercises")
    func testEditingStartsFromTheExistingExercises() {
        let presenter = DefineWorkoutWrapperPresenter(
            interactor: Interactor(),
            router: Router(),
            exercises: [flowTemplateExercise(exercise: flowExercise(name: "Squat"))]
        )

        #expect(presenter.exercises.map(\.exercise.name) == ["Squat"])
    }

    /// The screen used to dismiss on the same tick it started the save, so the failure alert was
    /// torn down before it could be read. Now nothing is saved twice and the flag clears after.
    @Test("Test A Second Tap During A Save Is Ignored")
    func testASecondTapDuringASaveIsIgnored() async {
        let screen = makeScreen()
        screen.presenter.exercises = [flowTemplateExercise(exercise: flowExercise())]
        screen.interactor.saveDelay = .milliseconds(150)

        screen.presenter.onConfirmPressed(delegate: delegate())
        screen.presenter.onConfirmPressed(delegate: delegate())

        #expect(await TestManagers.eventually { !screen.interactor.savedTemplates.isEmpty })
        try? await Task.sleep(for: .milliseconds(100))
        #expect(screen.interactor.savedTemplates.count == 1)
        #expect(!screen.presenter.isSaving)
    }

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let screen = makeScreen()

        screen.presenter.onViewAppear()
        screen.presenter.onViewDisappear()

        #expect(screen.interactor.trackedScreenEventNames == ["DefineWorkoutWrapperView_Appear"])
        #expect(screen.interactor.trackedEventNames == ["DefineWorkoutWrapperView_Disappear"])
    }
}
