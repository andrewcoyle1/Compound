//
//  CreateProgramFlowPresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

/// A failure for the interactor doubles to throw, so the tests can drive the unhappy path.
private struct ProgramFlowTestError: Error { }

/// A flag a `@Sendable` completion closure can set.
///
/// Every step of this wizard copies the previous step's `onComplete` onto the delegate it builds,
/// and that closure is what returns the user to onboarding once the program is saved. Dropping it
/// cannot be seen by comparing delegates — the only way to know it survived is to call it.
private final class CompletionFlag: @unchecked Sendable {
    private(set) var fired = false

    func fire() {
        fired = true
    }
}

/// The first screen of creating a training program: an explainer with a Next button.
///
/// It holds nothing, so the only thing it can get wrong is losing the caller's completion handler
/// — the one that returns an onboarding user to where they left off once the program is saved.
@MainActor
struct ProgramFlowCreateProgramPresenterTests {

    private final class Interactor: SpyGlobalInteractor, CreateProgramInteractor { }

    private final class Router: CreateProgramRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var nameDelegates: [NameProgramDelegate] = []

        func showNameProgramView(delegate: NameProgramDelegate) {
            nameDelegates.append(delegate)
        }
    }

    private struct Screen {
        let presenter: CreateProgramPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen() -> Screen {
        let interactor = Interactor()
        let router = Router()
        return Screen(
            presenter: CreateProgramPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    @Test("Test Next Opens The Naming Step")
    func testNextOpensTheNamingStep() {
        let screen = makeScreen()

        screen.presenter.onNextPressed(delegate: CreateProgramDelegate())

        #expect(screen.router.nameDelegates.count == 1)
    }

    /// When onboarding opens this flow it passes a completion handler, and onboarding cannot
    /// resume without it. It has to be copied onto every delegate from here to the last step.
    @Test("Test The Completion Handler Reaches The Naming Step")
    func testTheCompletionHandlerReachesTheNamingStep() {
        let screen = makeScreen()
        let flag = CompletionFlag()

        screen.presenter.onNextPressed(delegate: CreateProgramDelegate(onComplete: { flag.fire() }))
        screen.router.nameDelegates.first?.onComplete?()

        #expect(flag.fired)
    }

    /// Opened from the library rather than onboarding, there is no handler to carry, and the next
    /// step must be told that — it is what decides between resuming onboarding and just closing.
    @Test("Test No Completion Handler Is Carried When There Was None")
    func testNoCompletionHandlerIsCarriedWhenThereWasNone() {
        let screen = makeScreen()

        screen.presenter.onNextPressed(delegate: CreateProgramDelegate())

        #expect(screen.router.nameDelegates.first?.onComplete == nil)
    }

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let screen = makeScreen()

        screen.presenter.onViewAppear()

        #expect(screen.interactor.trackedScreenEventNames == ["CreateProgramView_Appear"])
    }
}

/// Naming the program.
///
/// The name typed here is the only thing this screen produces, and it has two more screens to
/// travel through before it reaches the saved program.
@MainActor
struct ProgramFlowNameProgramPresenterTests {

    private final class Interactor: SpyGlobalInteractor, NameProgramInteractor { }

    private final class Router: NameProgramRouter {
        private(set) var iconDelegates: [ProgramIconDelegate] = []

        func showProgramIconView(delegate: ProgramIconDelegate) {
            iconDelegates.append(delegate)
        }
    }

    private struct Screen {
        let presenter: NameProgramPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen() -> Screen {
        let interactor = Interactor()
        let router = Router()
        return Screen(
            presenter: NameProgramPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    /// Someone who has nothing in mind can press Next immediately, so the field starts on today's
    /// date rather than empty.
    @Test("Test The Name Starts As Todays Date")
    func testTheNameStartsAsTodaysDate() {
        let screen = makeScreen()

        #expect(screen.presenter.programName == Date.now.formattedDate)
        #expect(screen.presenter.canSave)
    }

    @Test("Test An Empty Name Cannot Be Saved")
    func testAnEmptyNameCannotBeSaved() {
        let screen = makeScreen()
        screen.presenter.programName = ""

        #expect(!screen.presenter.canSave)
    }

    /// Whitespace alone passed the old check.
    @Test("Test A Blank Name Cannot Be Saved And A Padded One Is Trimmed")
    func testABlankNameCannotBeSavedAndAPaddedOneIsTrimmed() {
        let screen = makeScreen()
        screen.presenter.programName = "  \n"
        #expect(!screen.presenter.canSave)
        screen.presenter.onNextPressed(delegate: NameProgramDelegate())
        #expect(screen.router.iconDelegates.isEmpty)

        screen.presenter.programName = "  Block "
        screen.presenter.onNextPressed(delegate: NameProgramDelegate())
        #expect(screen.router.iconDelegates.first?.name == "Block")
    }

    @Test("Test The Typed Name Reaches The Icon Step")
    func testTheTypedNameReachesTheIconStep() {
        let screen = makeScreen()
        screen.presenter.programName = "Hypertrophy Block"

        screen.presenter.onNextPressed(delegate: NameProgramDelegate())

        #expect(screen.router.iconDelegates.first?.name == "Hypertrophy Block")
    }

    @Test("Test The Completion Handler Reaches The Icon Step")
    func testTheCompletionHandlerReachesTheIconStep() {
        let screen = makeScreen()
        let flag = CompletionFlag()

        screen.presenter.onNextPressed(delegate: NameProgramDelegate(onComplete: { flag.fire() }))
        screen.router.iconDelegates.first?.onComplete?()

        #expect(flag.fired)
    }

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let screen = makeScreen()

        screen.presenter.onViewAppear()

        #expect(screen.interactor.trackedScreenEventNames == ["NameProgramView_Appear"])
    }
}

/// Choosing the program's colour and icon.
///
/// This is the step that mints the program's identity: its id and its author. Everything the
/// previous two screens collected has to arrive at the design screen alongside it.
@MainActor
struct ProgramFlowProgramIconPresenterTests {

    private final class Interactor: SpyGlobalInteractor, ProgramIconInteractor {
        var userId: String?

        init(userId: String? = "user-1") {
            self.userId = userId
        }
    }

    private final class Router: ProgramIconRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var designDelegates: [ProgramDesignDelegate] = []

        func showProgramDesignView(delegate: ProgramDesignDelegate) {
            designDelegates.append(delegate)
        }
    }

    private struct Screen {
        let presenter: ProgramIconPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen(userId: String? = "user-1") -> Screen {
        let interactor = Interactor(userId: userId)
        let router = Router()
        return Screen(
            presenter: ProgramIconPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    @Test("Test A Colour And Icon Are Chosen To Begin With")
    func testAColourAndIconAreChosenToBeginWith() {
        let screen = makeScreen()

        #expect(screen.presenter.selectedColour == ProgramIconPresenter.defaultColours.first)
        #expect(screen.presenter.selectedIcon == ProgramIconPresenter.defaultIcons.first)
    }

    @Test("Test Pressing A Colour Selects It")
    func testPressingAColourSelectsIt() {
        let screen = makeScreen()

        screen.presenter.onColourPressed(colour: .green)

        #expect(screen.presenter.selectedColour == .green)
    }

    @Test("Test Pressing An Icon Selects It")
    func testPressingAnIconSelectsIt() {
        let screen = makeScreen()

        screen.presenter.onIconPressed(icon: "sailboat.fill")

        #expect(screen.presenter.selectedIcon == "sailboat.fill")
    }

    /// The name came from two screens back and is never shown here, which is exactly what makes it
    /// easy to drop when this step builds the design screen's delegate by hand.
    @Test("Test The Name Colour And Icon Reach The Design Step")
    func testTheNameColourAndIconReachTheDesignStep() {
        let screen = makeScreen()
        screen.presenter.onColourPressed(colour: .green)
        screen.presenter.onIconPressed(icon: "sailboat.fill")

        screen.presenter.onNextPressed(delegate: ProgramIconDelegate(name: "Hypertrophy Block"))

        let delegate = screen.router.designDelegates.first
        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["selection", "selection"])
        #expect(delegate?.name == "Hypertrophy Block")
        #expect(delegate?.colour == .green)
        #expect(delegate?.icon == "sailboat.fill")
    }

    /// The program is stamped with its author here, and the saved document is filed under that
    /// user — a program authored by the wrong person would not come back on the next sign-in.
    @Test("Test The Program Is Authored By The Signed In User")
    func testTheProgramIsAuthoredBySignedInUser() {
        let screen = makeScreen(userId: "user-7")

        screen.presenter.onNextPressed(delegate: ProgramIconDelegate(name: "Block"))

        #expect(screen.router.designDelegates.first?.authorId == "user-7")
    }

    /// Two programs created in a row must not share an id, or saving the second overwrites the
    /// first.
    @Test("Test Each Program Is Given Its Own Identifier")
    func testEachProgramIsGivenItsOwnIdentifier() {
        let screen = makeScreen()

        screen.presenter.onNextPressed(delegate: ProgramIconDelegate(name: "Block"))
        screen.presenter.onNextPressed(delegate: ProgramIconDelegate(name: "Block"))

        #expect(screen.router.designDelegates.count == 2)
        #expect(screen.router.designDelegates.first?.id.isEmpty == false)
        #expect(screen.router.designDelegates.first?.id != screen.router.designDelegates.last?.id)
    }

    /// Without a signed-in user there is nobody to author the program, so the step refuses to go
    /// on rather than creating one owned by nobody.
    @Test("Test A Signed Out User Cannot Reach The Design Step")
    func testASignedOutUserCannotReachTheDesignStep() {
        let screen = makeScreen(userId: nil)

        screen.presenter.onNextPressed(delegate: ProgramIconDelegate(name: "Block"))

        #expect(screen.router.designDelegates.isEmpty)
    }

    @Test("Test The Completion Handler Reaches The Design Step")
    func testTheCompletionHandlerReachesTheDesignStep() {
        let screen = makeScreen()
        let flag = CompletionFlag()

        screen.presenter.onNextPressed(delegate: ProgramIconDelegate(onComplete: { flag.fire() }, name: "Block"))
        screen.router.designDelegates.first?.onComplete?()

        #expect(flag.fired)
    }

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let screen = makeScreen()

        screen.presenter.onViewAppear()

        #expect(screen.interactor.trackedScreenEventNames == ["ProgramIconView_Appear"])
    }
}

/// Laying out the days of a program: adding, removing, renaming and ordering them.
///
/// This is where the program actually takes shape, and two things make it risky. The days are
/// auto-named ("Workout A", "Workout B", "Rest Day") from their contents, so a rest day in the
/// middle must not consume a letter and a name the user typed must never be overwritten. And the
/// settings sheet edits the same program through a `Binding` from behind this screen, so anything
/// this screen keeps a private copy of can silently diverge from what will be saved.
@MainActor
struct ProgramFlowProgramDesignPresenterTests {

    private final class Interactor: SpyGlobalInteractor, ProgramDesignInteractor {
        var userId: String? = "user-1"
        var currentUser: UserModel?
        var favouriteGymProfile: GymProfileModel?
        var activeTrainingProgram: TrainingProgram?
        var saveProgramError: Error?
        var saveDelay: Duration = .zero
        private(set) var savedPrograms: [TrainingProgram] = []
        private(set) var savedTemplates: [WorkoutTemplateModel] = []
        private(set) var activatedProgramIds: [String] = []

        func setActiveTrainingProgram(programId: String) async throws {
            activatedProgramIds.append(programId)
        }

        func saveTrainingProgram(trainingProgram: TrainingProgram) async throws {
            try? await Task.sleep(for: saveDelay)
            if let saveProgramError { throw saveProgramError }
            savedPrograms.append(trainingProgram)
        }

        func saveWorkoutTemplate(workoutTemplate: WorkoutTemplateModel, image: PlatformImage?) async throws {
            savedTemplates.append(workoutTemplate)
        }
    }

    /// The onboarding destinations come from `SpyOnboardingRouter`, since this screen can hand a user straight back into onboarding once the program is saved.
    private final class Router: SpyOnboardingRouter, ProgramDesignRouter {
        private(set) var renameDelegates: [RenameWorkoutTemplateModelDelegate] = []
        private(set) var settingsBindings: [Binding<TrainingProgram>] = []

        func showRenameWorkoutTemplateModelView(delegate: RenameWorkoutTemplateModelDelegate) {
            renameDelegates.append(delegate)
        }

        func showProgramSettingsView(program: Binding<TrainingProgram>) {
            settingsBindings.append(program)
            record("programSettings")
        }
    }

    private struct Screen {
        let presenter: ProgramDesignPresenter
        let interactor: Interactor
        let router: Router
    }

    private func program(days: [WorkoutTemplateModel] = []) -> TrainingProgram {
        TrainingProgram(
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

    private func makeScreen(program: TrainingProgram? = nil) -> Screen {
        let interactor = Interactor()
        let router = Router()
        return Screen(
            presenter: ProgramDesignPresenter(
                interactor: interactor,
                router: router,
                program: program ?? self.program()
            ),
            interactor: interactor,
            router: router
        )
    }

    /// The `Binding` the view hands to the settings sheet, rebuilt here so a test can drive the settings round trip the way the toolbar button does.
    private func programBinding(_ presenter: ProgramDesignPresenter) -> Binding<TrainingProgram> {
        Binding(
            get: { MainActor.assumeIsolated { presenter.program } },
            set: { newValue in MainActor.assumeIsolated { presenter.program = newValue } }
        )
    }

    // MARK: - Starting state

    /// A brand new program arrives with no days at all, and a program with nothing in it cannot be
    /// laid out — so one rest day is created and selected to start from.
    @Test("Test A New Program Starts With One Selected Day")
    func testANewProgramStartsWithOneSelectedDay() {
        let screen = makeScreen()

        #expect(screen.presenter.dayPlans.count == 1)
        #expect(screen.presenter.selectedWorkoutTemplateModel.id == screen.presenter.dayPlans.first?.id)
        #expect(screen.presenter.program.workoutTemplates.count == 1)
    }

    @Test("Test An Existing Program Opens On Its First Day")
    func testAnExistingProgramOpensOnItsFirstDay() {
        let screen = makeScreen(program: program(days: [day("Push"), day("Pull")]))

        #expect(screen.presenter.dayPlans.map(\.name) == ["Push", "Pull"])
        #expect(screen.presenter.selectedWorkoutTemplateModel.name == "Push")
    }

    /// The program is what gets saved, so anything shown as a day has to be in it too.
    @Test("Test The Days Shown Are The Days That Will Be Saved")
    func testTheDaysShownAreTheDaysThatWillBeSaved() {
        let screen = makeScreen(program: program(days: [day("Push"), day("Pull")]))

        screen.presenter.onAddDayPressed()

        #expect(screen.presenter.program.workoutTemplates.map(\.id) == screen.presenter.dayPlans.map(\.id))
    }

    // MARK: - Adding and removing days

    @Test("Test Adding A Day Appends It And Selects It")
    func testAddingADayAppendsItAndSelectsIt() {
        let screen = makeScreen(program: program(days: [day("Push")]))

        screen.presenter.onAddDayPressed()

        #expect(screen.presenter.dayPlans.count == 2)
        #expect(screen.presenter.selectedWorkoutTemplateModel.id == screen.presenter.dayPlans.last?.id)
    }

    /// A program with no days cannot be trained, so the last one cannot be removed.
    @Test("Test The Last Day Cannot Be Removed")
    func testTheLastDayCannotBeRemoved() {
        let screen = makeScreen(program: program(days: [day("Push")]))

        #expect(!screen.presenter.canRemoveWorkoutTemplateModel)

        screen.presenter.onRemoveWorkoutTemplateModelPressed()

        #expect(screen.presenter.dayPlans.count == 1)
    }

    /// Removing the day being edited has to leave a different day selected, or the screen would be pointing at something that no longer exists.
    @Test("Test Removing The Selected Day Selects Another")
    func testRemovingTheSelectedDaySelectsAnother() {
        let screen = makeScreen(program: program(days: [day("Push"), day("Pull")]))
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
            program: program(days: [day("Rest", exercises: 1), day("Rest"), day("Rest", exercises: 1)])
        )

        screen.presenter.onAddDayPressed()

        #expect(screen.presenter.dayPlans.map(\.name) == ["Workout A", "Rest Day", "Workout B", "Rest Day"])
    }

    /// Adding exercises to a rest day turns it into a workout, and the letters behind it have to
    /// shuffle up to match.
    @Test("Test Filling A Day Renames It And The Days After It")
    func testFillingADayRenamesItAndTheDaysAfterIt() {
        let screen = makeScreen(program: program(days: [day("Rest"), day("Rest", exercises: 1)]))
        screen.presenter.onWorkoutTemplateModelSelected(screen.presenter.dayPlans[0])

        screen.presenter.selectedWorkoutTemplateModelExercises.wrappedValue = [
            WorkoutTemplateExercise(exercise: ExerciseModel.mock, setRestTimers: false)
        ]

        #expect(screen.presenter.dayPlans.map(\.name) == ["Workout A", "Workout B"])
    }

    /// Exercises must land on the day that was selected, not on whichever day happens to be first.
    @Test("Test Exercises Are Written To The Selected Day")
    func testExercisesAreWrittenToTheSelectedDay() {
        let screen = makeScreen(program: program(days: [day("Push"), day("Pull")]))
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
        let screen = makeScreen(program: program(days: [day("Rest", exercises: 1)]))

        screen.presenter.onRenameWorkoutTemplateModelPressed()
        screen.router.renameDelegates.first?.onSave("Leg Day")
        screen.presenter.onAddDayPressed()

        #expect(screen.presenter.dayPlans.map(\.name) == ["Leg Day", "Rest Day"])
    }

    /// The rename sheet is opened for the day being edited, and has to be handed that day's current
    /// name to start from.
    @Test("Test Renaming Starts From The Selected Days Name")
    func testRenamingStartsFromTheSelectedDaysName() {
        let screen = makeScreen(program: program(days: [day("Push"), day("Pull")]))
        screen.presenter.onWorkoutTemplateModelSelected(screen.presenter.dayPlans[1])

        screen.presenter.onRenameWorkoutTemplateModelPressed()

        #expect(screen.router.renameDelegates.first?.initialName == "Pull")
    }

    @Test("Test A Renamed Day Is Renamed In The Program")
    func testARenamedDayIsRenamedInTheProgram() {
        let screen = makeScreen(program: program(days: [day("Push")]))

        screen.presenter.onRenameWorkoutTemplateModelPressed()
        screen.router.renameDelegates.first?.onSave("Leg Day")

        #expect(screen.presenter.program.workoutTemplates.first?.name == "Leg Day")
        #expect(screen.presenter.selectedWorkoutTemplateModel.name == "Leg Day")
    }

    // MARK: - The settings sheet

    /// The settings sheet edits the program in place, through a binding onto this screen's program.
    @Test("Test Settings Are Given The Program To Edit")
    func testSettingsAreGivenTheProgramToEdit() {
        let screen = makeScreen()

        screen.presenter.onProgramSettingsPressed(program: programBinding(screen.presenter))

        #expect(screen.router.settingsBindings.first?.wrappedValue.id == "program-1")
    }

    /// Reordering the days in settings decides what is trained on which day. It used to be written
    /// into the program while this screen carried on showing — and then saving — its own stale copy
    /// of the old order, so the reorder was silently undone by the next edit.
    @Test("Test Reordering The Days In Settings Survives The Next Edit")
    func testReorderingTheDaysInSettingsSurvivesTheNextEdit() {
        let screen = makeScreen(program: program(days: [day("Push"), day("Pull"), day("Legs")]))
        let binding = programBinding(screen.presenter)

        screen.presenter.onProgramSettingsPressed(program: binding)
        let reordered = [screen.presenter.dayPlans[2], screen.presenter.dayPlans[0], screen.presenter.dayPlans[1]]
        screen.router.settingsBindings.first?.wrappedValue.workoutTemplates = reordered

        #expect(screen.presenter.dayPlans.map(\.name) == ["Legs", "Push", "Pull"])

        screen.presenter.onAddDayPressed()

        #expect(screen.presenter.dayPlans.map(\.name) == ["Legs", "Push", "Pull", "Rest Day"])
        #expect(screen.presenter.program.workoutTemplates.map(\.name) == ["Legs", "Push", "Pull", "Rest Day"])
    }

    /// The same divergence would lose the deload and cycle-count settings, which are what turn a
    /// week of days into a block of training.
    @Test("Test The Deload And Cycle Settings Survive The Next Edit")
    func testTheDeloadAndCycleSettingsSurviveTheNextEdit() {
        let screen = makeScreen(program: program(days: [day("Push")]))
        let binding = programBinding(screen.presenter)

        binding.wrappedValue.deload = .end
        binding.wrappedValue.numMicrocycles = 4
        screen.presenter.onAddDayPressed()

        #expect(screen.presenter.program.deload == .end)
        #expect(screen.presenter.program.numMicrocycles == 4)
    }

    // MARK: - Saving and activating

    @Test("Test Saving Stores The Program As It Stands")
    func testSavingStoresTheProgramAsItStands() async {
        let screen = makeScreen(program: program(days: [day("Push", exercises: 1)]))
        screen.presenter.onAddDayPressed()

        screen.presenter.onSavePressed(delegate: ProgramDesignDelegate(
            id: "program-1", authorId: "user-1", name: "Block", colour: .red, icon: "flag"
        ))

        #expect(await TestManagers.eventually { screen.interactor.savedPrograms.count == 1 })
        #expect(screen.interactor.savedPrograms.first?.workoutTemplates.count == 2)
        #expect(await TestManagers.eventually { screen.interactor.playedHaptics.map { "\($0)" } == ["success"] })
    }

    /// A save that fails must not look like it worked. The alert it raises goes through a
    /// `GlobalRouter` extension method, which is statically dispatched and so cannot be recorded by
    /// a double — what is checked here is that nothing was stored.
    @Test("Test A Failed Save Stores Nothing")
    func testAFailedSaveStoresNothing() async {
        let screen = makeScreen(program: program(days: [day("Push", exercises: 1)]))
        screen.interactor.saveProgramError = ProgramFlowTestError()

        screen.presenter.onSavePressed(delegate: ProgramDesignDelegate(
            id: "program-1", authorId: "user-1", name: "Block", colour: .red, icon: "flag"
        ))

        _ = await TestManagers.eventually(timeout: .milliseconds(200)) { !screen.interactor.savedPrograms.isEmpty }
        #expect(screen.interactor.savedPrograms.isEmpty)
        #expect(await TestManagers.eventually { screen.interactor.playedHaptics.map { "\($0)" } == ["error"] })
    }

    /// The screen shows an "active" badge, and it is keyed on the program being edited rather than
    /// on there merely being an active program.
    @Test("Test The Program Knows Whether It Is The Active One")
    func testTheProgramKnowsWhetherItIsTheActiveOne() {
        let screen = makeScreen()

        #expect(!screen.presenter.isProgramActive)

        screen.interactor.activeTrainingProgram = program()

        #expect(screen.presenter.isProgramActive)
    }

    private func designDelegate(onComplete: (@Sendable () -> Void)? = nil) -> ProgramDesignDelegate {
        ProgramDesignDelegate(onComplete: onComplete, id: "program-1", authorId: "user-1", name: "Block", colour: .red, icon: "flag")
    }
    @Test("Test A Program Of Rest Days Cannot Be Saved Or Activated")
    func testAProgramOfRestDaysCannotBeSavedOrActivated() async {
        let screen = makeScreen()
        #expect(!screen.presenter.canSave)

        screen.presenter.onSavePressed(delegate: designDelegate())
        screen.presenter.onActivatePressed(delegate: designDelegate())
        _ = await TestManagers.eventually(timeout: .milliseconds(200)) { !screen.interactor.savedPrograms.isEmpty }
        #expect(screen.interactor.savedPrograms.isEmpty)
        #expect(screen.router.alertTitles.isEmpty)

        screen.presenter.selectedWorkoutTemplateModelExercises.wrappedValue = [
            WorkoutTemplateExercise(exercise: ExerciseModel.mock, setRestTimers: false)
        ]
        #expect(screen.presenter.canSave)
    }

    /// Save had no in-flight state, so a second tap mid-save stored the program twice.
    @Test("Test A Second Tap During A Save Stores Nothing Extra")
    func testASecondTapDuringASaveStoresNothingExtra() async {
        let screen = makeScreen(program: program(days: [day("Push", exercises: 1)]))
        screen.interactor.saveDelay = .milliseconds(150)

        screen.presenter.onSavePressed(delegate: designDelegate())
        #expect(screen.presenter.isSaving)
        screen.presenter.onSavePressed(delegate: designDelegate())

        _ = await TestManagers.eventually { !screen.interactor.savedPrograms.isEmpty }
        try? await Task.sleep(for: .milliseconds(100))
        #expect(screen.interactor.savedPrograms.count == 1)
        #expect(!screen.presenter.isSaving)
    }

    /// The screen used to route onboarding itself and never call the closure onboarding passed.
    @Test("Test Finishing During Onboarding Calls The Completion Handler")
    func testFinishingDuringOnboardingCallsTheCompletionHandler() async {
        let screen = makeScreen(program: program(days: [day("Push", exercises: 1)]))
        let flag = CompletionFlag()

        await screen.presenter.activateProgram(delegate: designDelegate(onComplete: { flag.fire() }))

        #expect(flag.fired)
        #expect(screen.interactor.activatedProgramIds == ["program-1"])
    }

    /// "Yes" files each workout day as its own template; a rest day is not a workout.
    @Test("Test Activating With Templates Skips The Rest Days")
    func testActivatingWithTemplatesSkipsTheRestDays() async {
        let screen = makeScreen(program: program(days: [day("Push", exercises: 1), day("Rest"), day("Pull", exercises: 2)]))

        await screen.presenter.saveTemplatesAndActivate(delegate: designDelegate())

        #expect(screen.interactor.activatedProgramIds == ["program-1"])
        #expect(Set(screen.interactor.savedTemplates.map(\.name)) == ["Push", "Pull"])
    }

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let screen = makeScreen()

        screen.presenter.onViewAppear()

        #expect(screen.interactor.trackedScreenEventNames == ["ProgramDesignView_Appear"])
    }
}
