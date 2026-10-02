//
//  MesocycleDesignPresenterTests.swift
//  CompoundUnitTests
//
//  Split out of CreateMesocycleFlowPresenterTests.swift, which reached the 750-line file limit.
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

/// A failure for the interactor doubles to throw, so the tests can drive the unhappy path.
private struct MesocycleFlowTestError: Error { }

/// A flag a `@Sendable` completion closure can set.
///
/// Every step of this wizard copies the previous step's `onComplete` onto the delegate it builds,
/// and that closure is what returns the user to onboarding once the mesocycle is saved. Dropping it
/// cannot be seen by comparing delegates — the only way to know it survived is to call it.
private final class CompletionFlag: @unchecked Sendable {
    private(set) var fired = false

    func fire() {
        fired = true
    }
}

/// Laying out the days of a mesocycle: adding, removing, renaming and ordering them.
///
/// This is where the mesocycle actually takes shape, and two things make it risky. The days are
/// auto-named ("Workout A", "Workout B", "Rest Day") from their contents, so a rest day in the
/// middle must not consume a letter and a name the user typed must never be overwritten. And the
/// settings sheet edits the same mesocycle through a `Binding` from behind this screen, so anything
/// this screen keeps a private copy of can silently diverge from what will be saved.
@MainActor
struct MesocycleDesignFlowTests {

    private final class Interactor: SpyGlobalInteractor, MesocycleDesignInteractor {
        var userId: String? = "user-1"
        var currentUser: UserModel?
        var favouriteGymProfile: GymProfileModel?
        var activeMesocycle: Mesocycle?
        var saveMesocycleError: Error?
        var saveDelay: Duration = .zero
        private(set) var savedMesocycles: [Mesocycle] = []
        private(set) var savedTemplates: [WorkoutTemplateModel] = []
        private(set) var activatedMesocycleIds: [String] = []

        func setActiveMesocycle(mesocycleId: String) async throws {
            activatedMesocycleIds.append(mesocycleId)
        }

        private(set) var deletedMesocycleIds: [String] = []
        func deleteMesocycle(mesocycleId: String) async throws {
            deletedMesocycleIds.append(mesocycleId)
        }

        func saveMesocycle(mesocycle: Mesocycle) async throws {
            try? await Task.sleep(for: saveDelay)
            if let saveMesocycleError { throw saveMesocycleError }
            savedMesocycles.append(mesocycle)
        }

        func saveWorkoutTemplate(workoutTemplate: WorkoutTemplateModel, image: PlatformImage?) async throws {
            savedTemplates.append(workoutTemplate)
        }
    }

    /// The onboarding destinations come from `SpyOnboardingRouter`, since this screen can hand a user straight back into onboarding once the mesocycle is saved.
    private final class Router: SpyOnboardingRouter, MesocycleDesignRouter {
        private(set) var renameDelegates: [RenameWorkoutTemplateModelDelegate] = []
        private(set) var settingsBindings: [Binding<Mesocycle>] = []

        func showRenameWorkoutTemplateModelView(delegate: RenameWorkoutTemplateModelDelegate) {
            renameDelegates.append(delegate)
        }

        func showMesocycleSettingsView(mesocycle: Binding<Mesocycle>) {
            settingsBindings.append(mesocycle)
            record("programSettings")
        }

        func showShareToFollowerView(delegate: ShareToFollowerDelegate) {
            record("shareToFollower")
        }
    }

    private struct Screen {
        let presenter: MesocycleDesignPresenter
        let interactor: Interactor
        let router: Router
    }

    private func mesocycle(days: [WorkoutTemplateModel] = []) -> Mesocycle {
        Mesocycle(
            id: "program-1",
            authorId: "user-1",
            name: "Block",
            icon: "flag",
            colour: "#FF0000",
            workoutTemplates: days
        )
    }

    private func day(_ name: String, exercises: Int = 0) -> WorkoutTemplateModel {
        WorkoutTemplateModel(
            id: UUID().uuidString,
            authorId: "user-1",
            name: name,
            exercises: (0..<exercises).map { _ in
                WorkoutTemplateExercise(exercise: ExerciseModel.mock, setRestTimers: false)
            }
        )
    }

    private func makeScreen(mesocycle: Mesocycle? = nil) -> Screen {
        let interactor = Interactor()
        let router = Router()
        return Screen(
            presenter: MesocycleDesignPresenter(
                interactor: interactor,
                router: router,
                mesocycle: mesocycle ?? self.mesocycle()
            ),
            interactor: interactor,
            router: router
        )
    }

    /// The `Binding` the view hands to the settings sheet, rebuilt here so a test can drive the settings round trip the way the toolbar button does.
    private func mesocycleBinding(_ presenter: MesocycleDesignPresenter) -> Binding<Mesocycle> {
        Binding(
            get: { MainActor.assumeIsolated { presenter.mesocycle } },
            set: { newValue in MainActor.assumeIsolated { presenter.mesocycle = newValue } }
        )
    }

    // MARK: - Starting state

    /// A brand new mesocycle arrives with no days at all, and a mesocycle with nothing in it cannot be
    /// laid out — so one rest day is created and selected to start from.
    @Test("Test A New Program Starts With One Selected Day")
    func testANewMesocycleStartsWithOneSelectedDay() {
        let screen = makeScreen()

        #expect(screen.presenter.dayPlans.count == 1)
        #expect(screen.presenter.selectedWorkoutTemplateModel.id == screen.presenter.dayPlans.first?.id)
        #expect(screen.presenter.mesocycle.workoutTemplates.count == 1)
    }

    @Test("Test An Existing Program Opens On Its First Day")
    func testAnExistingMesocycleOpensOnItsFirstDay() {
        let screen = makeScreen(mesocycle: mesocycle(days: [day("Push"), day("Pull")]))

        #expect(screen.presenter.dayPlans.map(\.name) == ["Push", "Pull"])
        #expect(screen.presenter.selectedWorkoutTemplateModel.name == "Push")
    }

    /// The mesocycle is what gets saved, so anything shown as a day has to be in it too.
    @Test("Test The Days Shown Are The Days That Will Be Saved")
    func testTheDaysShownAreTheDaysThatWillBeSaved() {
        let screen = makeScreen(mesocycle: mesocycle(days: [day("Push"), day("Pull")]))

        screen.presenter.onAddDayPressed()

        #expect(screen.presenter.mesocycle.workoutTemplates.map(\.id) == screen.presenter.dayPlans.map(\.id))
    }

    // MARK: - Adding and removing days

    @Test("Test Adding A Day Appends It And Selects It")
    func testAddingADayAppendsItAndSelectsIt() {
        let screen = makeScreen(mesocycle: mesocycle(days: [day("Push")]))

        screen.presenter.onAddDayPressed()

        #expect(screen.presenter.dayPlans.count == 2)
        #expect(screen.presenter.selectedWorkoutTemplateModel.id == screen.presenter.dayPlans.last?.id)
    }

    /// A mesocycle with no days cannot be trained, so the last one cannot be removed.
    @Test("Test The Last Day Cannot Be Removed")
    func testTheLastDayCannotBeRemoved() {
        let screen = makeScreen(mesocycle: mesocycle(days: [day("Push")]))

        #expect(!screen.presenter.canRemoveWorkoutTemplateModel)

        screen.presenter.onRemoveWorkoutTemplateModelPressed()

        #expect(screen.presenter.dayPlans.count == 1)
    }

    /// Removing the day being edited has to leave a different day selected, or the screen would be pointing at something that no longer exists.
    @Test("Test Removing The Selected Day Selects Another")
    func testRemovingTheSelectedDaySelectsAnother() {
        let screen = makeScreen(mesocycle: mesocycle(days: [day("Push"), day("Pull")]))
        screen.presenter.onWorkoutTemplateModelSelected(screen.presenter.dayPlans[1])
        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["selection"])

        screen.presenter.onRemoveWorkoutTemplateModelPressed()

        #expect(screen.presenter.dayPlans.map(\.name) == ["Push"])
        #expect(screen.presenter.selectedWorkoutTemplateModel.name == "Push")
    }

    // MARK: - Automatic day names

    /// Days are lettered in the order they are trained, and rest days are not workouts — a rest day
    /// between two sessions must not take "Workout B" and leave the second session as "Workout C".
    @Test("Test Rest Days Do Not Consume A Workout Letter")
    func testRestDaysDoNotConsumeAWorkoutLetter() {
        let screen = makeScreen(
            mesocycle: mesocycle(days: [day("Rest", exercises: 1), day("Rest"), day("Rest", exercises: 1)])
        )

        screen.presenter.onAddDayPressed()

        #expect(screen.presenter.dayPlans.map(\.name) == ["Workout A", "Rest Day", "Workout B", "Rest Day"])
    }

    /// Adding exercises to a rest day turns it into a workout, and the letters behind it have to
    /// shuffle up to match.
    @Test("Test Filling A Day Renames It And The Days After It")
    func testFillingADayRenamesItAndTheDaysAfterIt() {
        let screen = makeScreen(mesocycle: mesocycle(days: [day("Rest"), day("Rest", exercises: 1)]))
        screen.presenter.onWorkoutTemplateModelSelected(screen.presenter.dayPlans[0])

        screen.presenter.selectedWorkoutTemplateModelExercises.wrappedValue = [
            WorkoutTemplateExercise(exercise: ExerciseModel.mock, setRestTimers: false)
        ]

        #expect(screen.presenter.dayPlans.map(\.name) == ["Workout A", "Workout B"])
    }

    /// Exercises must land on the day that was selected, not on whichever day happens to be first.
    @Test("Test Exercises Are Written To The Selected Day")
    func testExercisesAreWrittenToTheSelectedDay() {
        let screen = makeScreen(mesocycle: mesocycle(days: [day("Push"), day("Pull")]))
        screen.presenter.onWorkoutTemplateModelSelected(screen.presenter.dayPlans[1])

        screen.presenter.selectedWorkoutTemplateModelExercises.wrappedValue = [
            WorkoutTemplateExercise(exercise: ExerciseModel.mock, setRestTimers: false)
        ]

        #expect(screen.presenter.dayPlans[0].exercises.isEmpty)
        #expect(screen.presenter.dayPlans[1].exercises.count == 1)
        #expect(screen.presenter.selectedWorkoutTemplateModel.exercises.count == 1)
    }

    /// A name the user typed is theirs. Only the generated names are re-generated.
    @Test("Test A Typed Day Name Survives Later Edits")
    func testATypedDayNameSurvivesLaterEdits() {
        let screen = makeScreen(mesocycle: mesocycle(days: [day("Rest", exercises: 1)]))

        screen.presenter.onRenameWorkoutTemplateModelPressed()
        screen.router.renameDelegates.first?.onSave("Leg Day")
        screen.presenter.onAddDayPressed()

        #expect(screen.presenter.dayPlans.map(\.name) == ["Leg Day", "Rest Day"])
    }

    /// The rename sheet is opened for the day being edited, and has to be handed that day's current
    /// name to start from.
    @Test("Test Renaming Starts From The Selected Days Name")
    func testRenamingStartsFromTheSelectedDaysName() {
        let screen = makeScreen(mesocycle: mesocycle(days: [day("Push"), day("Pull")]))
        screen.presenter.onWorkoutTemplateModelSelected(screen.presenter.dayPlans[1])

        screen.presenter.onRenameWorkoutTemplateModelPressed()

        #expect(screen.router.renameDelegates.first?.initialName == "Pull")
    }

    @Test("Test A Renamed Day Is Renamed In The Program")
    func testARenamedDayIsRenamedInTheMesocycle() {
        let screen = makeScreen(mesocycle: mesocycle(days: [day("Push")]))

        screen.presenter.onRenameWorkoutTemplateModelPressed()
        screen.router.renameDelegates.first?.onSave("Leg Day")

        #expect(screen.presenter.mesocycle.workoutTemplates.first?.name == "Leg Day")
        #expect(screen.presenter.selectedWorkoutTemplateModel.name == "Leg Day")
    }

    // MARK: - The settings sheet

    /// The settings sheet edits the mesocycle in place, through a binding onto this screen's mesocycle.
    @Test("Test Settings Are Given The Program To Edit")
    func testSettingsAreGivenTheMesocycleToEdit() {
        let screen = makeScreen()

        screen.presenter.onMesocycleSettingsPressed(mesocycle: mesocycleBinding(screen.presenter))

        #expect(screen.router.settingsBindings.first?.wrappedValue.id == "program-1")
    }

    /// Reordering the days in settings decides what is trained on which day. It used to be written
    /// into the mesocycle while this screen carried on showing — and then saving — its own stale copy
    /// of the old order, so the reorder was silently undone by the next edit.
    @Test("Test Reordering The Days In Settings Survives The Next Edit")
    func testReorderingTheDaysInSettingsSurvivesTheNextEdit() {
        let screen = makeScreen(mesocycle: mesocycle(days: [day("Push"), day("Pull"), day("Legs")]))
        let binding = mesocycleBinding(screen.presenter)

        screen.presenter.onMesocycleSettingsPressed(mesocycle: binding)
        let reordered = [screen.presenter.dayPlans[2], screen.presenter.dayPlans[0], screen.presenter.dayPlans[1]]
        screen.router.settingsBindings.first?.wrappedValue.workoutTemplates = reordered

        #expect(screen.presenter.dayPlans.map(\.name) == ["Legs", "Push", "Pull"])

        screen.presenter.onAddDayPressed()

        #expect(screen.presenter.dayPlans.map(\.name) == ["Legs", "Push", "Pull", "Rest Day"])
        #expect(screen.presenter.mesocycle.workoutTemplates.map(\.name) == ["Legs", "Push", "Pull", "Rest Day"])
    }

    /// The same divergence would lose the deload and cycle-count settings, which are what turn a
    /// week of days into a block of training.
    @Test("Test The Deload And Cycle Settings Survive The Next Edit")
    func testTheDeloadAndCycleSettingsSurviveTheNextEdit() {
        let screen = makeScreen(mesocycle: mesocycle(days: [day("Push")]))
        let binding = mesocycleBinding(screen.presenter)

        binding.wrappedValue.deload = .end
        binding.wrappedValue.numMicrocycles = 4
        screen.presenter.onAddDayPressed()

        #expect(screen.presenter.mesocycle.deload == .end)
        #expect(screen.presenter.mesocycle.numMicrocycles == 4)
    }

    // MARK: - Saving and activating

    @Test("Test Saving Stores The Program As It Stands")
    func testSavingStoresTheMesocycleAsItStands() async {
        let screen = makeScreen(mesocycle: mesocycle(days: [day("Push", exercises: 1)]))
        screen.presenter.onAddDayPressed()

        screen.presenter.onSavePressed(delegate: MesocycleDesignDelegate(
            id: "program-1", authorId: "user-1", name: "Block", colour: .red, icon: "flag"
        ))

        #expect(await TestManagers.eventually { screen.interactor.savedMesocycles.count == 1 })
        #expect(screen.interactor.savedMesocycles.first?.workoutTemplates.count == 2)
        #expect(await TestManagers.eventually { screen.interactor.playedHaptics.map { "\($0)" } == ["success"] })
    }

    /// A save that fails must not look like it worked. The alert it raises goes through a
    /// `GlobalRouter` extension method, which is statically dispatched and so cannot be recorded by
    /// a double — what is checked here is that nothing was stored.
    @Test("Test A Failed Save Stores Nothing")
    func testAFailedSaveStoresNothing() async {
        let screen = makeScreen(mesocycle: mesocycle(days: [day("Push", exercises: 1)]))
        screen.interactor.saveMesocycleError = MesocycleFlowTestError()

        screen.presenter.onSavePressed(delegate: MesocycleDesignDelegate(
            id: "program-1", authorId: "user-1", name: "Block", colour: .red, icon: "flag"
        ))

        _ = await TestManagers.eventually(timeout: .milliseconds(200)) { !screen.interactor.savedMesocycles.isEmpty }
        #expect(screen.interactor.savedMesocycles.isEmpty)
        #expect(await TestManagers.eventually { screen.interactor.playedHaptics.map { "\($0)" } == ["error"] })
    }

    /// The screen shows an "active" badge, and it is keyed on the mesocycle being edited rather than
    /// on there merely being an active mesocycle.
    @Test("Test The Program Knows Whether It Is The Active One")
    func testTheMesocycleKnowsWhetherItIsTheActiveOne() {
        let screen = makeScreen()

        #expect(!screen.presenter.isMesocycleActive)

        screen.interactor.activeMesocycle = mesocycle()

        #expect(screen.presenter.isMesocycleActive)
    }

    private func designDelegate(onComplete: (@Sendable () -> Void)? = nil) -> MesocycleDesignDelegate {
        MesocycleDesignDelegate(onComplete: onComplete, id: "program-1", authorId: "user-1", name: "Block", colour: .red, icon: "flag")
    }
    @Test("Test A Program Of Rest Days Cannot Be Saved Or Activated")
    func testAMesocycleOfRestDaysCannotBeSavedOrActivated() async {
        let screen = makeScreen()
        #expect(!screen.presenter.canSave)

        screen.presenter.onSavePressed(delegate: designDelegate())
        screen.presenter.onActivatePressed(delegate: designDelegate())
        _ = await TestManagers.eventually(timeout: .milliseconds(200)) { !screen.interactor.savedMesocycles.isEmpty }
        #expect(screen.interactor.savedMesocycles.isEmpty)
        #expect(screen.router.alertTitles.isEmpty)

        screen.presenter.selectedWorkoutTemplateModelExercises.wrappedValue = [
            WorkoutTemplateExercise(exercise: ExerciseModel.mock, setRestTimers: false)
        ]
        #expect(screen.presenter.canSave)
    }

    /// Save had no in-flight state, so a second tap mid-save stored the mesocycle twice.
    @Test("Test A Second Tap During A Save Stores Nothing Extra")
    func testASecondTapDuringASaveStoresNothingExtra() async {
        let screen = makeScreen(mesocycle: mesocycle(days: [day("Push", exercises: 1)]))
        screen.interactor.saveDelay = .milliseconds(150)

        screen.presenter.onSavePressed(delegate: designDelegate())
        #expect(screen.presenter.isSaving)
        screen.presenter.onSavePressed(delegate: designDelegate())

        _ = await TestManagers.eventually { !screen.interactor.savedMesocycles.isEmpty }
        try? await Task.sleep(for: .milliseconds(100))
        #expect(screen.interactor.savedMesocycles.count == 1)
        #expect(!screen.presenter.isSaving)
    }

    /// The screen used to route onboarding itself and never call the closure onboarding passed.
    @Test("Test Finishing During Onboarding Calls The Completion Handler")
    func testFinishingDuringOnboardingCallsTheCompletionHandler() async {
        let screen = makeScreen(mesocycle: mesocycle(days: [day("Push", exercises: 1)]))
        let flag = CompletionFlag()

        await screen.presenter.activateMesocycle(delegate: designDelegate(onComplete: { flag.fire() }))

        #expect(flag.fired)
        #expect(screen.interactor.activatedMesocycleIds == ["program-1"])
    }

    /// "Yes" files each workout day as its own template; a rest day is not a workout.
    @Test("Test Activating With Templates Skips The Rest Days")
    func testActivatingWithTemplatesSkipsTheRestDays() async {
        let screen = makeScreen(mesocycle: mesocycle(days: [day("Push", exercises: 1), day("Rest"), day("Pull", exercises: 2)]))

        await screen.presenter.saveTemplatesAndActivate(delegate: designDelegate())

        #expect(screen.interactor.activatedMesocycleIds == ["program-1"])
        #expect(Set(screen.interactor.savedTemplates.map(\.name)) == ["Push", "Pull"])
    }

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let screen = makeScreen()

        screen.presenter.onViewAppear()

        #expect(screen.interactor.trackedScreenEventNames == ["ProgramDesignView_Appear"])
    }

    // MARK: - Unsaved changes, share and delete

    /// Close used to ask "discard your changes?" when nothing had changed, and the edit sheet's
    /// swipe dropped real changes silently. Both now follow whether anything differs.
    @Test("Test Only A Real Edit Counts As Unsaved")
    func testOnlyARealEditCountsAsUnsaved() {
        let screen = makeScreen(mesocycle: mesocycle(days: [day("Push", exercises: 1)]))
        #expect(!screen.presenter.hasUnsavedChanges)

        screen.presenter.onWorkoutTemplateModelSelected(screen.presenter.dayPlans[0])
        #expect(!screen.presenter.hasUnsavedChanges)

        screen.presenter.onAddDayPressed()
        #expect(screen.presenter.hasUnsavedChanges)
    }

    @Test("Test A Settings Change Counts As Unsaved")
    func testASettingsChangeCountsAsUnsaved() {
        let screen = makeScreen(mesocycle: mesocycle(days: [day("Push", exercises: 1)]))

        mesocycleBinding(screen.presenter).wrappedValue.numMicrocycles = 4

        #expect(screen.presenter.hasUnsavedChanges)
    }

    @Test("Test Sharing From The Editor Opens The Share Sheet")
    func testSharingFromTheEditorOpensTheShareSheet() {
        let screen = makeScreen()

        screen.presenter.onSharePressed()

        #expect(screen.router.shown == ["shareToFollower"])
    }

    @Test("Test Deleting From The Editor Deletes The Program")
    func testDeletingFromTheEditorDeletesTheMesocycle() async {
        let screen = makeScreen()

        await screen.presenter.deleteMesocycle()

        #expect(screen.interactor.deletedMesocycleIds == ["program-1"])
        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["success"])
    }
}
