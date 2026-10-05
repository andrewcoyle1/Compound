//
//  CreateWorkoutFlowPresenterTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

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

// MARK: - Step 2: naming it

/// Naming the workout. The name typed here is the one the workout is saved under three screens
/// later, so it has to travel intact, and whitespace alone must not become a nameless workout in
/// the user's library.
@MainActor
struct WorkoutBuildNamePresenterTests {

    private final class Interactor: SpyGlobalInteractor, NameWorkoutInteractor {
        var gymProfiles: [GymProfileModel] = []
    }

    private final class Router: NameWorkoutRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var gymDelegates: [ChooseGymProfileDelegate] = []
        private(set) var defineDelegates: [DefineWorkoutWrapperDelegate] = []

        func showChooseGymProfileView(delegate: ChooseGymProfileDelegate) {
            gymDelegates.append(delegate)
        }

        func showDefineWorkoutWrapperView(delegate: DefineWorkoutWrapperDelegate) {
            defineDelegates.append(delegate)
        }
    }

    private func makeScreen(gyms: [GymProfileModel] = [], workoutName: String = "") -> (NameWorkoutPresenter, Router) {
        let router = Router()
        let interactor = Interactor()
        interactor.gymProfiles = gyms
        return (NameWorkoutPresenter(interactor: interactor, router: router, workoutName: workoutName), router)
    }

    @Test("Test A Workout Cannot Be Named Nothing")
    func testAWorkoutCannotBeNamedNothing() {
        let (presenter, _) = makeScreen()

        presenter.workoutName = "   \n "
        #expect(!presenter.canSave)

        presenter.workoutName = "Push Day"
        #expect(presenter.canSave)
    }

    @Test("Test The Typed Name Reaches The Gym Step")
    func testTheTypedNameReachesTheGymStep() {
        let (presenter, router) = makeScreen()
        presenter.workoutName = "Push Day"

        presenter.onContinuePressed(delegate: NameWorkoutDelegate())

        #expect(router.gymDelegates.first?.name == "Push Day")
    }

    @Test("Test The Name Is Trimmed Before It Travels")
    func testTheNameIsTrimmedBeforeItTravels() {
        let (presenter, router) = makeScreen()
        presenter.workoutName = "  Push Day \n"

        presenter.onContinuePressed(delegate: NameWorkoutDelegate())

        #expect(router.gymDelegates.first?.name == "Push Day")
    }

    @Test("Test Editing Opens With The Existing Name")
    func testEditingOpensWithTheExistingName() {
        let (presenter, _) = makeScreen(workoutName: "Leg Day")

        #expect(presenter.workoutName == "Leg Day")
    }

    /// A template being edited already has a gym, so the chooser is skipped and the template goes
    /// straight to the define step where the save keeps its id.
    @Test("Test Editing Skips The Gym Step When The Gym Still Exists")
    func testEditingSkipsTheGymStepWhenTheGymStillExists() {
        let gym = GymProfileModel(id: "gym-1", authorId: "user-1", name: "Home Gym")
        let (presenter, router) = makeScreen(gyms: [gym], workoutName: "Leg Day")
        let template = WorkoutTemplateModel(id: "wt-1", authorId: "user-1", name: "Leg Day", gymProfileId: "gym-1")

        presenter.onContinuePressed(delegate: NameWorkoutDelegate(workoutTemplate: template))

        #expect(router.gymDelegates.isEmpty)
        #expect(router.defineDelegates.first?.workoutTemplate?.id == "wt-1")
        #expect(router.defineDelegates.first?.gymProfile.id == "gym-1")
    }

    /// The gym may have been deleted since the template was made, so the chooser is shown again
    /// but the template still travels.
    /// With one gym there is nothing to choose, so the chooser is skipped for that gym.
    @Test("Test A Single Gym Skips The Gym Step")
    func testASingleGymSkipsTheGymStep() {
        let gym = GymProfileModel(id: "gym-1", authorId: "user-1", name: "Home Gym")
        let (presenter, router) = makeScreen(gyms: [gym], workoutName: "Push Day")

        presenter.onContinuePressed(delegate: NameWorkoutDelegate())

        #expect(router.gymDelegates.isEmpty)
        #expect(router.defineDelegates.first?.gymProfile.id == "gym-1")
        #expect(router.defineDelegates.first?.name == "Push Day")
    }

    @Test("Test Several Gyms Ask Which One")
    func testSeveralGymsAskWhichOne() {
        let gyms = [
            GymProfileModel(id: "gym-1", authorId: "user-1", name: "Home Gym"),
            GymProfileModel(id: "gym-2", authorId: "user-1", name: "Commercial")
        ]
        let (presenter, router) = makeScreen(gyms: gyms, workoutName: "Push Day")

        presenter.onContinuePressed(delegate: NameWorkoutDelegate())

        #expect(router.defineDelegates.isEmpty)
        #expect(router.gymDelegates.count == 1)
    }

    /// Return on the keyboard continues, but not past an empty name.
    @Test("Test Return Continues Only With A Name")
    func testReturnContinuesOnlyWithAName() {
        let (presenter, router) = makeScreen()

        presenter.onNameSubmitted(delegate: NameWorkoutDelegate())
        #expect(router.gymDelegates.isEmpty)

        presenter.workoutName = "Push Day"
        presenter.onNameSubmitted(delegate: NameWorkoutDelegate())
        #expect(router.gymDelegates.first?.name == "Push Day")
    }

    @Test("Test Editing Asks For A Gym When The Old One Is Gone")
    func testEditingAsksForAGymWhenTheOldOneIsGone() {
        let (presenter, router) = makeScreen(workoutName: "Leg Day")
        let template = WorkoutTemplateModel(id: "wt-1", authorId: "user-1", name: "Leg Day", gymProfileId: "gym-gone")

        presenter.onContinuePressed(delegate: NameWorkoutDelegate(workoutTemplate: template))

        #expect(router.defineDelegates.isEmpty)
        #expect(router.gymDelegates.first?.workoutTemplate?.id == "wt-1")
    }
}

// MARK: - Step 3: choosing where it will be done

/// Choosing which gym the workout belongs to. The screen only lists what the interactor holds, so
/// the risk is all in the hop: the name from the previous step, the gym just picked and the
/// creation callback have to arrive together at the define step.
@MainActor
struct WorkoutBuildGymChoicePresenterTests {

    private final class Interactor: SpyGlobalInteractor, ChooseGymProfileInteractor {
        var userId: String? = "user-1"
        var currentUser: UserModel? = UserModel(userId: "user-1")
        var favouriteGymProfile: GymProfileModel?
        var gymProfiles: [GymProfileModel] = []
        private(set) var deletedProfileIds: [String] = []

        func deleteGymProfile(_ profileId: String) async throws {
            deletedProfileIds.append(profileId)
        }
    }

    private final class Router: ChooseGymProfileRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var defineDelegates: [DefineWorkoutWrapperDelegate] = []
        private(set) var createGymProfileCount = 0

        func showDefineWorkoutWrapperView(delegate: DefineWorkoutWrapperDelegate) {
            defineDelegates.append(delegate)
        }

        func showCreateGymProfileView(delegate: CreateGymProfileDelegate) {
            createGymProfileCount += 1
        }
    }

    private struct Screen {
        let presenter: ChooseGymProfilePresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen() -> Screen {
        let interactor = Interactor()
        let router = Router()
        return Screen(
            presenter: ChooseGymProfilePresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    private func profile(_ id: String, name: String) -> GymProfileModel {
        GymProfileModel(id: id, authorId: "user-1", name: name)
    }

    @Test("Test The Gyms On File Are Listed")
    func testTheGymsOnFileAreListed() {
        let screen = makeScreen()
        screen.interactor.gymProfiles = [profile("gym-1", name: "Home Gym"), profile("gym-2", name: "Commercial")]

        #expect(screen.presenter.gymProfiles.map(\.name) == ["Home Gym", "Commercial"])
        #expect(screen.presenter.numGyms == 2)
    }

    /// The favourite is read off the stored profile rather than off the list, so it has to keep
    /// pointing at the gym the user actually favourited.
    @Test("Test The Favourite Gym Is Taken From The Profile")
    func testTheFavouriteGymIsTakenFromTheProfile() {
        let screen = makeScreen()
        screen.interactor.currentUser = UserModel(userId: "user-1", submittedFavouriteGymProfileId: "gym-2")
        screen.interactor.favouriteGymProfile = profile("gym-2", name: "Commercial")

        #expect(screen.presenter.favouriteGymProfileId == "gym-2")
        #expect(screen.presenter.favouriteGymProfile?.name == "Commercial")
    }

    /// The name has come two screens by now and is not shown on this one, which is exactly what
    /// makes it easy to drop here.
    @Test("Test The Name And Gym Reach The Define Step")
    func testTheNameAndGymReachTheDefineStep() {
        let screen = makeScreen()

        screen.presenter.onGymProfilePressed(
            name: "Push Day",
            profile: profile("gym-1", name: "Home Gym"),
            delegate: ChooseGymProfileDelegate(name: "Push Day")
        )

        #expect(screen.router.defineDelegates.first?.name == "Push Day")
        #expect(screen.router.defineDelegates.first?.gymProfile.id == "gym-1")
    }

    @Test("Test The Template Being Edited Reaches The Define Step")
    func testTheTemplateBeingEditedReachesTheDefineStep() {
        let screen = makeScreen()
        let template = WorkoutTemplateModel(id: "wt-1", authorId: "user-1", name: "Push Day")

        screen.presenter.onGymProfilePressed(
            name: "Push Day",
            profile: profile("gym-1", name: "Home Gym"),
            delegate: ChooseGymProfileDelegate(name: "Push Day", workoutTemplate: template)
        )

        #expect(screen.router.defineDelegates.first?.workoutTemplate?.id == "wt-1")
    }

    /// With no gyms on file the list was empty and the wizard could not continue.
    @Test("Test An Empty List Offers To Create A Gym")
    func testAnEmptyListOffersToCreateAGym() {
        let screen = makeScreen()

        screen.presenter.onCreateGymProfilePressed()

        #expect(screen.router.createGymProfileCount == 1)
    }

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let screen = makeScreen()

        screen.presenter.onViewAppear()
        screen.presenter.onViewDisappear()

        #expect(screen.interactor.trackedScreenEventNames == ["ChooseGymProfileView_Appear"])
        #expect(screen.interactor.trackedEventNames == ["ChooseGymProfileView_Disappear"])
    }
}

// MARK: - Step 4: the exercises and their targets

/// The screen where the workout is assembled: exercises added, removed and given set targets,
/// with a volume summary per muscle. The list is mirrored out of a `Binding` so SwiftUI notices
/// edits, and a one-way mirror would silently lose what the user added. The summary is the only
/// arithmetic here — it tells the user whether the workout is balanced, so an assisting muscle
/// counted as a worked one makes the workout read harder than it is.
@MainActor
struct WorkoutBuildDefinePresenterTests {

    private final class Interactor: SpyGlobalInteractor, DefineWorkoutInteractor {
        var currentUser: UserModel? = UserModel(userId: "user-1")

        func saveWorkoutTemplate(workoutTemplate: WorkoutTemplateModel, image: PlatformImage?) async throws { }
    }

    private final class Router: DefineWorkoutRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var pickerDelegates: [ExercisesPickerDelegate] = []
        private(set) var setTargetDelegates: [SetTargetDelegate] = []

        func showExercisesPickerView(delegate: ExercisesPickerDelegate) {
            pickerDelegates.append(delegate)
        }

        func showSetTargetView(delegate: SetTargetDelegate) {
            setTargetDelegates.append(delegate)
        }
    }

    private struct Screen {
        let presenter: DefineWorkoutPresenter
        let interactor: Interactor
        let router: Router
        let box: CreateWorkoutFlowExerciseBox
    }

    private func makeScreen(exercises: [WorkoutTemplateExercise] = []) -> Screen {
        let interactor = Interactor()
        let router = Router()
        let box = CreateWorkoutFlowExerciseBox(exercises)
        return Screen(
            presenter: DefineWorkoutPresenter(interactor: interactor, router: router, exercises: box.binding),
            interactor: interactor,
            router: router,
            box: box
        )
    }

    // MARK: The list and the binding behind it

    /// The parent owns the list, and a mirror that never writes back means the user removes an
    /// exercise, watches it disappear, and finds it again in the workout that gets saved. The same
    /// exercise can also appear twice in a workout — rows are told apart by their own id rather
    /// than by the exercise they hold — so removing one copy leaves the other standing.
    @Test("Test Removing An Exercise Reaches The Parent")
    func testRemovingAnExerciseReachesTheParent() {
        let bench = flowExercise(id: "bench", name: "Bench Press")
        let screen = makeScreen(exercises: [
            flowTemplateExercise(id: "a", exercise: bench),
            flowTemplateExercise(id: "b", exercise: bench),
            flowTemplateExercise(id: "c", exercise: flowExercise(name: "Row"))
        ])

        screen.presenter.removeExercise(exercise: screen.presenter.exercises[0])

        #expect(screen.presenter.exercises.map(\.id) == ["b", "c"])
        #expect(screen.box.value.map(\.id) == ["b", "c"])
    }

    // MARK: Adding exercises

    /// The picker writes through a binding into this screen's list: what is ticked there has to
    /// land in the workout and in the parent behind it, alongside what was already in it.
    @Test("Test Exercises Picked In The Picker Land In The Workout")
    func testExercisesPickedInThePickerLandInTheWorkout() {
        let bench = flowTemplateExercise(exercise: flowExercise(name: "Bench Press"))
        let screen = makeScreen(exercises: [bench])

        screen.presenter.onAddExercisePressed()
        screen.router.pickerDelegates.first?.addedExercises.wrappedValue.append(
            flowTemplateExercise(exercise: flowExercise(name: "Squat"))
        )

        #expect(screen.presenter.exercises.map(\.exercise.name) == ["Bench Press", "Squat"])
        #expect(screen.box.value.map(\.exercise.name) == ["Bench Press", "Squat"])
    }

    /// A new workout opens the picker by itself, the first time only: closing it leaves the user
    /// on an empty list they chose.
    @Test("Test An Empty New Workout Opens The Picker Once")
    func testAnEmptyNewWorkoutOpensThePickerOnce() {
        let screen = makeScreen()

        screen.presenter.onViewAppear(autoOpensPicker: true)
        screen.presenter.onViewAppear(autoOpensPicker: true)

        #expect(screen.router.pickerDelegates.count == 1)
    }

    @Test("Test A Workout With Exercises Does Not Open The Picker")
    func testAWorkoutWithExercisesDoesNotOpenThePicker() {
        let screen = makeScreen(exercises: [flowTemplateExercise(exercise: flowExercise())])

        screen.presenter.onViewAppear(autoOpensPicker: true)

        #expect(screen.router.pickerDelegates.isEmpty)
    }

    /// A mesocycle day with no exercises is a rest day, so nothing opens there.
    @Test("Test A Rest Day Does Not Open The Picker")
    func testARestDayDoesNotOpenThePicker() {
        let screen = makeScreen()

        screen.presenter.onViewAppear(autoOpensPicker: false)

        #expect(screen.router.pickerDelegates.isEmpty)
    }

    // MARK: Editing an exercise's targets

    /// The set-target sheet edits through the binding it is handed, so that binding has to point
    /// at the row that was tapped — otherwise the targets land on a different exercise.
    @Test("Test Set Targets Written By The Sheet Reach The Tapped Exercise")
    func testSetTargetsWrittenByTheSheetReachTheTappedExercise() {
        let bench = flowTemplateExercise(id: "a", exercise: flowExercise(name: "Bench Press"))
        let screen = makeScreen(exercises: [bench])
        let box = CreateWorkoutFlowExerciseBox([bench])

        screen.presenter.onExercisePressed(exercise: Binding(
            get: { MainActor.assumeIsolated { box.value[0] } },
            set: { newValue in MainActor.assumeIsolated { box.value[0] = newValue } }
        ))
        screen.router.setTargetDelegates.first?.exercise.wrappedValue.setTargets = [
            SetTarget(setNumber: 1, minReps: 6, maxReps: 8),
            SetTarget(setNumber: 2, minReps: 6, maxReps: 8)
        ]

        #expect(box.value[0].setTargets.map(\.setNumber) == [1, 2])
        #expect(box.value[0].setTargets.first?.minReps == 6)
    }

    // MARK: The muscle summary

    /// Three sets of an exercise that works the chest directly is three chest sets; a muscle that
    /// only assists counts half, which is what stops an accessory-heavy workout reading as if it
    /// trained everything hard.
    @Test("Test Worked Muscles Count Whole Sets And Assisting Ones Half")
    func testWorkedMusclesCountWholeSetsAndAssistingOnesHalf() {
        let exercise = flowExercise(muscles: [.chest: .primary, .triceps: .secondary])
        let screen = makeScreen(exercises: [flowTemplateExercise(exercise: exercise, setCount: 3)])

        let chest = screen.presenter.targetMuscleSummaries.first { $0.muscle == .chest }
        let triceps = screen.presenter.targetMuscleSummaries.first { $0.muscle == .triceps }
        #expect(chest?.weightedTargetSets == 3)
        #expect(chest?.exerciseCount == 1)
        #expect(triceps?.weightedTargetSets == 1.5)
        #expect(triceps?.exerciseCount == 1)
    }

    /// Volume for a muscle is the sum across every exercise that hits it, weighted per exercise
    /// rather than for the workout as a whole.
    @Test("Test Volume Adds Up Across Exercises")
    func testVolumeAddsUpAcrossExercises() {
        let press = flowExercise(id: "press", muscles: [.chest: .primary, .triceps: .secondary])
        let dip = flowExercise(id: "dip", muscles: [.chest: .secondary, .triceps: .primary])
        let screen = makeScreen(exercises: [
            flowTemplateExercise(exercise: press, setCount: 4),
            flowTemplateExercise(exercise: dip, setCount: 2)
        ])

        let chest = screen.presenter.targetMuscleSummaries.first { $0.muscle == .chest }
        let triceps = screen.presenter.targetMuscleSummaries.first { $0.muscle == .triceps }
        #expect(chest?.weightedTargetSets == 5)
        #expect(chest?.exerciseCount == 2)
        #expect(triceps?.weightedTargetSets == 4)
        #expect(triceps?.exerciseCount == 2)
    }

    /// An exercise with no targets yet trains nothing, so it must inflate neither the set count
    /// nor the number of exercises credited to the muscle.
    @Test("Test An Exercise With No Targets Adds No Volume")
    func testAnExerciseWithNoTargetsAddsNoVolume() {
        let exercise = flowExercise(muscles: [.chest: .primary])
        var empty = flowTemplateExercise(exercise: exercise)
        empty.setTargets = []
        let screen = makeScreen(exercises: [flowTemplateExercise(exercise: exercise, setCount: 2), empty])

        let chest = screen.presenter.targetMuscleSummaries.first { $0.muscle == .chest }
        #expect(chest?.weightedTargetSets == 2)
        #expect(chest?.exerciseCount == 1)
    }

    /// The summary is a horizontal strip, so the same workout must not shuffle its muscles
    /// between redraws just because a dictionary was iterated.
    @Test("Test The Summary Is Ordered By Muscle Name")
    func testTheSummaryIsOrderedByMuscleName() {
        let exercise = flowExercise(muscles: [.triceps: .secondary, .chest: .primary, .frontDelts: .secondary])
        let screen = makeScreen(exercises: [flowTemplateExercise(exercise: exercise, setCount: 2)])

        #expect(screen.presenter.targetMuscleSummaries.map(\.muscle.name) == ["Chest", "Front Delts", "Triceps"])
    }

    /// Built inline by the wrapper and the mesocycle designer, which log the screen; logging here
    /// too counted every visit twice.
    @Test("Test Appearing Logs No Screen Event")
    func testAppearingLogsNoScreenEvent() {
        let screen = makeScreen()

        screen.presenter.onViewAppear()

        #expect(screen.interactor.trackedScreenEventNames.isEmpty)
        #expect(screen.interactor.trackedEventNames.isEmpty)
    }
}

// MARK: - The exercise picker

/// Ticking exercises to add to the workout being defined. The picker works on a scratch list and
/// only writes into the workout on confirm, so what matters is that backing out leaves the
/// workout alone and confirming adds to it rather than replacing it.
@MainActor
struct WorkoutBuildPickerPresenterTests {

    private final class Interactor: SpyGlobalInteractor, ExercisesPickerInteractor { }

    /// `ExercisesPickerRouter` adds no requirements, and the presenter's only navigation is
    /// `dismissScreen()` — a `GlobalRouter` extension method, statically dispatched, so a double
    /// cannot observe it. The tests assert the committed list instead.
    private final class Router: ExercisesPickerRouter {
        let router: AnyRouter = TestRouting.anyRouter
    }

    private struct Screen {
        let presenter: ExercisesPickerPresenter
        let box: CreateWorkoutFlowExerciseBox
    }

    private func makeScreen(existing: [WorkoutTemplateExercise] = []) -> Screen {
        let box = CreateWorkoutFlowExerciseBox(existing)
        return Screen(
            presenter: ExercisesPickerPresenter(
                interactor: Interactor(),
                router: Router(),
                delegate: ExercisesPickerDelegate(addedExercises: box.binding)
            ),
            box: box
        )
    }

    /// The row is a toggle, so pressing a ticked exercise unticks that one rather than adding a
    /// second copy of it, and leaves the rest of the selection alone.
    @Test("Test Pressing A Selected Exercise Deselects It")
    func testPressingASelectedExerciseDeselectsIt() {
        let screen = makeScreen()
        let squat = flowExercise(id: "squat", name: "Squat")

        screen.presenter.onExercisePressed(exercise: flowExercise(id: "bench", name: "Bench Press"))
        screen.presenter.onExercisePressed(exercise: squat)
        screen.presenter.onExercisePressed(exercise: flowExercise(id: "row", name: "Row"))
        screen.presenter.onExercisePressed(exercise: squat)

        #expect(screen.presenter.workingExercises.map(\.exercise.name) == ["Bench Press", "Row"])
    }

    /// Nothing reaches the workout until the user confirms, so closing the picker after tapping
    /// around must not quietly add exercises.
    @Test("Test Ticking Without Confirming Changes Nothing")
    func testTickingWithoutConfirmingChangesNothing() {
        let screen = makeScreen()

        screen.presenter.onExercisePressed(exercise: flowExercise(name: "Bench Press"))
        screen.presenter.onDismissPressed()

        #expect(screen.box.value.isEmpty)
    }

    @Test("Test Confirming Adds The Selection To The Workout")
    func testConfirmingAddsTheSelectionToTheWorkout() {
        let existing = flowTemplateExercise(exercise: flowExercise(name: "Deadlift"))
        let screen = makeScreen(existing: [existing])

        screen.presenter.onExercisePressed(exercise: flowExercise(id: "bench", name: "Bench Press"))
        screen.presenter.onExercisePressed(exercise: flowExercise(id: "squat", name: "Squat"))
        screen.presenter.onSavePressed()

        #expect(screen.box.value.map(\.exercise.name) == ["Deadlift", "Bench Press", "Squat"])
    }

    /// A newly picked exercise arrives with one set already targeted and numbered from one, so
    /// the workout can be saved without opening the target sheet at all. Rest timers are a
    /// per-exercise override the user has not asked for, so they start off.
    /// The picker starts empty each time it opens, so confirming an exercise the workout already
    /// had appended it a second time.
    @Test("Test Confirming Does Not Add An Exercise The Workout Already Has")
    func testConfirmingDoesNotAddAnExerciseTheWorkoutAlreadyHas() {
        let squat = flowExercise(id: "squat", name: "Squat")
        let screen = makeScreen(existing: [flowTemplateExercise(exercise: squat)])

        screen.presenter.onExercisePressed(exercise: squat)
        screen.presenter.onExercisePressed(exercise: flowExercise(id: "lunge", name: "Lunge"))
        screen.presenter.onSavePressed()

        #expect(screen.box.value.map(\.exercise.name) == ["Squat", "Lunge"])
    }

    @Test("Test A Picked Exercise Starts With One Numbered Set")
    func testAPickedExerciseStartsWithOneNumberedSet() {
        let screen = makeScreen()

        screen.presenter.onExercisePressed(exercise: flowExercise(name: "Bench Press"))
        screen.presenter.onSavePressed()

        #expect(screen.box.value.first?.setTargets.map(\.setNumber) == [1])
        #expect(screen.box.value.first?.setRestTimers == false)
    }
}

// MARK: - The set-target sheet

/// The sheet that sets rep ranges per set for one exercise. Its editing is pinned in
/// `WorkoutBuildUnsavedChangesTests`; this pins the analytics.
@MainActor
struct WorkoutBuildSetTargetPresenterTests {

    private final class Interactor: SpyGlobalInteractor, SetTargetInteractor { }

    /// `SetTargetRouter` has no requirements, and `onDismissPressed()` goes through
    /// `dismissScreen()`, a `GlobalRouter` extension method that dispatches statically and never
    /// reaches this double. There is nothing to record.
    private final class Router: SetTargetRouter {
        let router: AnyRouter = TestRouting.anyRouter
    }

    private func makeScreen() -> (SetTargetPresenter, Interactor) {
        let interactor = Interactor()
        let box = CreateWorkoutFlowExerciseBox([flowTemplateExercise(exercise: flowExercise())])
        let exercise = Binding(
            get: { MainActor.assumeIsolated { box.value[0] } },
            set: { newValue in MainActor.assumeIsolated { box.value[0] = newValue } }
        )
        return (SetTargetPresenter(interactor: interactor, router: Router(), delegate: SetTargetDelegate(exercise: exercise)), interactor)
    }

    @Test("Test Appearing And Leaving Are Tracked Separately")
    func testAppearingAndLeavingAreTrackedSeparately() {
        let (presenter, interactor) = makeScreen()

        presenter.onViewAppear()
        presenter.onViewDisappear()

        #expect(interactor.trackedScreenEventNames == ["SetTargetView_Appear"])
        #expect(interactor.trackedEventNames == ["SetTargetView_Disappear"])
    }
}
