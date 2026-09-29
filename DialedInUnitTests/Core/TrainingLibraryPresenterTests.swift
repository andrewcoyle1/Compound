//
//  TrainingLibraryPresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//
//  The rest of the Training tab's read-mostly screens. Split from `TrainingHomePresenterTests`
//  only because one file for all eight suites runs past the 750-line lint limit; the shared
//  fixtures live there.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

// MARK: - Exercise settings

/// The per-exercise settings sheet: which units this exercise is logged in, how long its rest is,
/// and the note carried into every session of it.
///
/// Each setting has a subtitle that has to say what is actually stored — "Default (90s)" when there
/// is no override and a formatted custom time when there is — and clearing an override has to mean
/// removing it rather than storing zero seconds.
@MainActor
struct TrainingExerciseSettingsPresenterTests {

    private final class Interactor: SpyGlobalInteractor, ExerciseSettingsInteractor {
        var workoutSettings = WorkoutSettings(authorId: "author-1")
        var preference = ExerciseUnitPreference(exerciseModelId: "bench")
        var note: String?
        var restOverride: Int?
        private(set) var savedNotes: [String?] = []
        private(set) var savedRestOverrides: [Int?] = []
        private(set) var savedWeightUnits: [ExerciseWeightUnit] = []
        private(set) var savedDistanceUnits: [ExerciseDistanceUnit] = []

        func getPreference(templateId: String) -> ExerciseUnitPreference { preference }

        func setWeightUnit(_ unit: ExerciseWeightUnit, for templateId: String) { savedWeightUnits.append(unit) }

        func setDistanceUnit(_ unit: ExerciseDistanceUnit, for templateId: String) { savedDistanceUnits.append(unit) }

        func exerciseNote(for exerciseId: String) -> String? { note }

        func setExerciseNote(_ note: String?, for exerciseId: String) async throws { savedNotes.append(note) }

        func exerciseRestOverride(for exerciseId: String) -> Int? { restOverride }

        func setExerciseRestOverride(_ seconds: Int?, for exerciseId: String) async throws {
            savedRestOverrides.append(seconds)
        }
    }

    private final class Router: ExerciseSettingsRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var shown: [String] = []
        private(set) var noteDelegates: [WorkoutNotesDelegate] = []
        private(set) var restPrimaryActions: [() -> Void] = []
        private(set) var restMinutes: [Binding<Int>] = []
        private(set) var restSeconds: [Binding<Int>] = []

        func showExerciseModelDetailView(delegate: ExerciseModelDetailDelegate) { shown.append("exerciseDetail") }

        func showWorkoutNotesView(delegate: WorkoutNotesDelegate) {
            shown.append("notes")
            noteDelegates.append(delegate)
        }

        func showRestTimerSettingsView(delegate: RestTimerSettingsDelegate) {
            shown.append("restTimerSettings")
        }

        func showRestModal(
            primaryButtonAction: @escaping () -> Void,
            secondaryButtonAction: @escaping () -> Void,
            minutesSelection: Binding<Int>,
            secondsSelection: Binding<Int>
        ) {
            shown.append("rest")
            restPrimaryActions.append(primaryButtonAction)
            restMinutes.append(minutesSelection)
            restSeconds.append(secondsSelection)
        }
    }

    private struct Screen {
        let presenter: ExerciseSettingsPresenter
        let interactor: Interactor
        let router: Router
        let exercise: ExerciseModel
    }

    private func makeScreen(
        preference: ExerciseUnitPreference? = nil,
        note: String? = nil,
        restOverride: Int? = nil
    ) -> Screen {
        let exercise = TrainingTabFixture.exercise("Bench")
        let interactor = Interactor()
        if let preference { interactor.preference = preference }
        interactor.note = note
        interactor.restOverride = restOverride
        let router = Router()
        return Screen(
            presenter: ExerciseSettingsPresenter(interactor: interactor, router: router, exercise: exercise),
            interactor: interactor,
            router: router,
            exercise: exercise
        )
    }

    // MARK: - Subtitles

    @Test("Test The Units Row Names Both Units")
    func testTheUnitsRowNamesBothUnits() {
        let screen = makeScreen(
            preference: ExerciseUnitPreference(exerciseModelId: "bench", weightUnit: .pounds, distanceUnit: .miles)
        )

        #expect(screen.presenter.weightsSubtitle == "Pounds · Miles")
    }

    /// With no override the row has to show the global default, so the user can see what they are
    /// about to change before they change it.
    @Test("Test Rest Shows The Global Default When Nothing Is Overridden")
    func testRestShowsTheGlobalDefaultWhenNothingIsOverridden() {
        let screen = makeScreen()
        screen.interactor.workoutSettings.defaultRestDurationSeconds = 120

        #expect(screen.presenter.restSubtitle == "Default (120s)")
    }

    @Test("Test A Custom Rest Reads As Minutes And Seconds")
    func testACustomRestReadsAsMinutesAndSeconds() {
        #expect(makeScreen(restOverride: 150).presenter.restSubtitle == "Custom (2m 30s)")
    }

    /// Seconds are padded, so sixty-five seconds reads "1m 05s" rather than "1m 5s".
    @Test("Test Single Digit Seconds Are Padded")
    func testSingleDigitSecondsArePadded() {
        #expect(makeScreen(restOverride: 65).presenter.restSubtitle == "Custom (1m 05s)")
    }

    @Test("Test An Empty Note Reads As None")
    func testAnEmptyNoteReadsAsNone() {
        #expect(makeScreen(note: "   ").presenter.noteSubtitle == "None")
    }

    /// The row is one line, so a multi-line note is previewed by its first line rather than
    /// collapsing into a run-on.
    @Test("Test A Multi Line Note Is Previewed By Its First Line")
    func testAMultiLineNoteIsPreviewedByItsFirstLine() {
        #expect(makeScreen(note: "Elbows tucked\nPause at chest").presenter.noteSubtitle == "Elbows tucked")
    }

    // MARK: - Units

    @Test("Test Choosing A Weight Unit Saves It And Keeps The Distance Unit")
    func testChoosingAWeightUnitSavesItAndKeepsTheDistanceUnit() {
        let screen = makeScreen(
            preference: ExerciseUnitPreference(exerciseModelId: "bench", weightUnit: .kilograms, distanceUnit: .miles)
        )

        screen.presenter.onSelectWeightUnit(.pounds)

        #expect(screen.interactor.savedWeightUnits == [.pounds])
        #expect(screen.presenter.weightsSubtitle == "Pounds · Miles")
    }

    @Test("Test Choosing A Distance Unit Saves It And Keeps The Weight Unit")
    func testChoosingADistanceUnitSavesItAndKeepsTheWeightUnit() {
        let screen = makeScreen(
            preference: ExerciseUnitPreference(exerciseModelId: "bench", weightUnit: .pounds, distanceUnit: .meters)
        )

        screen.presenter.onSelectDistanceUnit(.miles)

        #expect(screen.interactor.savedDistanceUnits == [.miles])
        #expect(screen.presenter.weightsSubtitle == "Pounds · Miles")
    }

    // MARK: - Rest

    /// The picker opens on the time already set, so editing an override is an adjustment rather
    /// than re-entering it from zero.
    @Test("Test The Rest Picker Opens On The Time Already Set")
    func testTheRestPickerOpensOnTheTimeAlreadySet() {
        let screen = makeScreen(restOverride: 150)

        screen.presenter.onRestTimerPressed()

        #expect(screen.presenter.restPickerMinutes == 2)
        #expect(screen.presenter.restPickerSeconds == 30)
    }

    @Test("Test The Rest Picker Opens At Zero When Nothing Is Overridden")
    func testTheRestPickerOpensAtZeroWhenNothingIsOverridden() {
        let screen = makeScreen()
        screen.presenter.restPickerMinutes = 4

        screen.presenter.onRestTimerPressed()

        #expect(screen.presenter.restPickerMinutes == 0)
        #expect(screen.presenter.restPickerSeconds == 0)
    }

    @Test("Test Confirming The Picker Saves The Chosen Rest")
    func testConfirmingThePickerSavesTheChosenRest() async {
        let screen = makeScreen()
        screen.presenter.onRestTimerPressed()

        screen.router.restMinutes.first.map { $0.wrappedValue = 1 }
        screen.router.restSeconds.first.map { $0.wrappedValue = 45 }
        screen.router.restPrimaryActions.first?()
        await TestManagers.eventually { !screen.interactor.savedRestOverrides.isEmpty }

        #expect(screen.interactor.savedRestOverrides == [105])
        #expect(screen.presenter.restSubtitle == "Custom (1m 45s)")
    }

    /// Winding the picker back to zero means "use the default again", so the override is removed
    /// rather than stored as a rest of no seconds.
    @Test("Test Winding The Picker To Zero Clears The Override")
    func testWindingThePickerToZeroClearsTheOverride() async {
        let screen = makeScreen(restOverride: 150)
        screen.interactor.workoutSettings.defaultRestDurationSeconds = 90
        screen.presenter.onRestTimerPressed()

        screen.router.restMinutes.first.map { $0.wrappedValue = 0 }
        screen.router.restSeconds.first.map { $0.wrappedValue = 0 }
        screen.router.restPrimaryActions.first?()
        await TestManagers.eventually { !screen.interactor.savedRestOverrides.isEmpty }

        #expect(screen.interactor.savedRestOverrides == [Int?.none])
        #expect(screen.presenter.restSubtitle == "Default (90s)")
    }

    // MARK: - Note

    @Test("Test Saving A Note Stores It Trimmed")
    func testSavingANoteStoresItTrimmed() async {
        let screen = makeScreen()
        screen.presenter.onNotePressed()

        screen.router.noteDelegates.first.map { $0.notes.wrappedValue = "  Elbows tucked  " }
        screen.router.noteDelegates.first?.onSave()
        await TestManagers.eventually { !screen.interactor.savedNotes.isEmpty }

        #expect(screen.interactor.savedNotes == ["Elbows tucked"])
    }

    /// Emptying the note removes it rather than storing a blank string, so the row goes back to
    /// reading "None".
    @Test("Test Emptying A Note Removes It")
    func testEmptyingANoteRemovesIt() async {
        let screen = makeScreen(note: "Elbows tucked")
        screen.presenter.onNotePressed()

        screen.router.noteDelegates.first.map { $0.notes.wrappedValue = "   " }
        screen.router.noteDelegates.first?.onSave()
        await TestManagers.eventually { !screen.interactor.savedNotes.isEmpty }

        #expect(screen.interactor.savedNotes == [String?.none])
        #expect(screen.presenter.noteSubtitle == "None")
    }

    @Test("Test Info Opens The Exercise Detail")
    func testInfoOpensTheExerciseDetail() {
        let screen = makeScreen()

        screen.presenter.onInfoPressed()

        #expect(screen.router.shown == ["exerciseDetail"])
    }

    @Test("Test Appearing And Leaving Are Both Tracked")
    func testAppearingAndLeavingAreBothTracked() {
        let screen = makeScreen()
        let delegate = ExerciseSettingsDelegate(exercise: screen.exercise)

        screen.presenter.onViewAppear(delegate: delegate)
        screen.presenter.onViewDisappear(delegate: delegate)

        #expect(screen.interactor.trackedScreenEventNames == ["ExerciseSettingsView_Appear"])
        #expect(screen.interactor.trackedEventNames == ["ExerciseSettingsView_Disappear"])
    }
}

// MARK: - Workout history

/// Every workout the user has finished, newest first.
///
/// The list is headed "Completed Workouts" and counted in that header, so what it holds has to be
/// finished work: not the session running right now, and not the rest days the active program
/// pre-creates for dates that have not arrived.
@MainActor
struct TrainingWorkoutHistoryPresenterTests {

    private final class Interactor: SpyGlobalInteractor, WorkoutHistoryInteractor {
        var currentUser: UserModel?
        var workoutSessions: [WorkoutSessionModel] = []
        private(set) var syncCount = 0

        func syncAllRemoteDataIfLoggedIn() async { syncCount += 1 }
    }

    private final class Router: WorkoutHistoryRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var shown: [String] = []
        private(set) var sessionDetailDelegates: [WorkoutSessionDetailDelegate] = []

        func showDevSettingsView() { shown.append("devSettings") }

        func showWorkoutSessionDetailView(delegate: WorkoutSessionDetailDelegate) {
            shown.append("sessionDetail")
            sessionDetailDelegates.append(delegate)
        }
    }

    private struct Screen {
        let presenter: WorkoutHistoryPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen(sessions: [WorkoutSessionModel] = []) -> Screen {
        let interactor = Interactor()
        interactor.workoutSessions = sessions
        let router = Router()
        return Screen(
            presenter: WorkoutHistoryPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    @Test("Test The Most Recent Workout Is First")
    func testTheMostRecentWorkoutIsFirst() {
        let screen = makeScreen(sessions: [
            TrainingTabFixture.session(id: "older", on: TrainingTabFixture.date(day: 9)),
            TrainingTabFixture.session(id: "newest", on: TrainingTabFixture.date(day: 13)),
            TrainingTabFixture.session(id: "middle", on: TrainingTabFixture.date(day: 11))
        ])

        #expect(screen.presenter.workoutSessions.map(\.id) == ["newest", "middle", "older"])
    }

    /// The workout being logged right now is saved the moment it starts, so it sits in the same
    /// collection as finished ones. It is not history yet — and its row would draw with no date
    /// and no duration.
    @Test("Test The Workout Still Running Is Not In The History")
    func testTheWorkoutStillRunningIsNotInTheHistory() {
        let screen = makeScreen(sessions: [
            TrainingTabFixture.session(id: "done", on: TrainingTabFixture.date(day: 11)),
            TrainingTabFixture.session(id: "live", on: TrainingTabFixture.date(day: 13), finished: false)
        ])

        #expect(screen.presenter.workoutSessions.map(\.id) == ["done"])
    }

    /// Rest days for days still to come are written ahead of time by the program. Listing one puts
    /// tomorrow at the top of the user's history.
    @Test("Test A Rest Day Yet To Come Is Not In The History")
    func testARestDayYetToComeIsNotInTheHistory() {
        let screen = makeScreen(sessions: [
            TrainingTabFixture.session(id: "done", on: TrainingTabFixture.date(day: 11)),
            TrainingTabFixture.session(
                id: "future-rest",
                name: "Rest",
                on: Date().addingTimeInterval(86_400),
                isRestDay: true
            )
        ])

        #expect(screen.presenter.workoutSessions.map(\.id) == ["done"])
    }

    @Test("Test A Rest Day Already Taken Stays In The History")
    func testARestDayAlreadyTakenStaysInTheHistory() {
        let screen = makeScreen(sessions: [
            TrainingTabFixture.session(id: "past-rest", name: "Rest", on: TrainingTabFixture.date(day: 11), isRestDay: true)
        ])

        #expect(screen.presenter.workoutSessions.map(\.id) == ["past-rest"])
    }

    @Test("Test Pressing A Workout Opens It")
    func testPressingAWorkoutOpensIt() {
        let screen = makeScreen()
        let session = TrainingTabFixture.session(id: "s1", name: "Push", on: TrainingTabFixture.date(day: 11))

        screen.presenter.onWorkoutSessionPressed(session: session, layoutMode: .tabBar)

        #expect(screen.router.sessionDetailDelegates.first?.initialSession.id == "s1")
        #expect(screen.presenter.selectedSession?.id == "s1")
    }

    /// Reload is the empty state's retry. Sessions arrive through a live listener, so it re-runs
    /// the remote sync and reports both ends of it.
    @Test("Test Reload Re-Runs The Remote Sync")
    func testReloadReRunsTheRemoteSync() async {
        let screen = makeScreen()

        screen.presenter.onReloadPressed()
        await TestManagers.eventually { !screen.presenter.isLoading }

        #expect(screen.interactor.syncCount == 1)
        #expect(screen.interactor.trackedEventNames == [
            "WorkoutHistoryView_SyncSessions_Start",
            "WorkoutHistoryView_SyncSessions_Success"
        ])
    }

    /// Tapping reload twice is one sync, not two — otherwise an impatient user fans out a request
    /// per tap.
    @Test("Test Reloading Twice Only Syncs Once")
    func testReloadingTwiceOnlySyncsOnce() async {
        let screen = makeScreen()

        screen.presenter.onReloadPressed()
        screen.presenter.onReloadPressed()
        await TestManagers.eventually { !screen.presenter.isLoading }

        #expect(screen.interactor.syncCount == 1)
    }

    @Test("Test Appearing And Leaving Are Both Tracked")
    func testAppearingAndLeavingAreBothTracked() {
        let screen = makeScreen()

        screen.presenter.onViewAppear()
        screen.presenter.onViewDisappear()

        #expect(screen.interactor.trackedScreenEventNames == ["WorkoutHistoryView_Appear"])
        #expect(screen.interactor.trackedEventNames == ["WorkoutHistoryView_Disappear"])
    }
}

// MARK: - Program library

/// The training program library: the one program in use, and the ones saved for later.
///
/// The saved list has to exclude whichever program is active, or the active program appears twice —
/// once at the top of the screen and once among the alternatives.
@MainActor
struct TrainingProgramManagementPresenterTests {

    private final class Interactor: SpyGlobalInteractor, TrainingProgramLibraryInteractor {
        var activeTrainingProgram: TrainingProgram?
        var trainingPrograms: [TrainingProgram] = []
        var prebuiltPrograms: [TrainingProgram] = []
        var deleteError: Error?
        private(set) var activatedProgramIds: [String] = []
        private(set) var deletedProgramIds: [String] = []

        func setActiveTrainingProgram(programId: String) async throws { activatedProgramIds.append(programId) }

        func deleteTrainingProgram(programId: String) async throws {
            if let deleteError { throw deleteError }
            deletedProgramIds.append(programId)
        }
    }

    private final class Router: TrainingProgramLibraryRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var shown: [String] = []
        private(set) var editDelegates: [EditTrainingProgramDelegate] = []

        /// Bound on the class declaring the conformance, or the protocol's default implementation
        /// runs and the alert escapes to the real router unseen.
        private(set) var alertTitles: [String] = []

        func showAlert(error: Error) { alertTitles.append("Error") }
        private(set) var alertSubtitles: [String?] = []

        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) {
            alertTitles.append(title)
            alertSubtitles.append(subtitle)
        }
        func showSimpleAlert(title: String, subtitle: String?) { alertTitles.append(title) }

        func showDevSettingsView() { shown.append("devSettings") }
        func showProgramSettingsView(program: Binding<TrainingProgram>) { shown.append("programSettings") }
        func showCreateProgramView(delegate: CreateProgramDelegate) { shown.append("createProgram") }
        func showPrebuiltProgramDetailView(program: TrainingProgram) { shown.append("prebuilt:\(program.id)") }

        func showEditTrainingProgramView(delegate: EditTrainingProgramDelegate) {
            shown.append("editProgram")
            editDelegates.append(delegate)
        }
    }

    private struct Screen {
        let presenter: TrainingProgramLibraryPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen(programs: [TrainingProgram] = [], active: TrainingProgram? = nil) -> Screen {
        let interactor = Interactor()
        interactor.trainingPrograms = programs
        interactor.activeTrainingProgram = active
        let router = Router()
        return Screen(
            presenter: TrainingProgramLibraryPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    @Test("Test The Active Program Is Left Out Of The Saved List")
    func testTheActiveProgramIsLeftOutOfTheSavedList() {
        let push = TrainingTabFixture.program("Push Pull Legs", id: "ppl")
        let upper = TrainingTabFixture.program("Upper Lower", id: "ul")
        let screen = makeScreen(programs: [push, upper], active: push)

        #expect(screen.presenter.nonActiveTrainingPrograms.map(\.id) == ["ul"])
        #expect(screen.presenter.savedPrograms.count == 2)
    }

    @Test("Test With No Program In Use Every Saved Program Is Offered")
    func testWithNoProgramInUseEverySavedProgramIsOffered() {
        let screen = makeScreen(programs: [
            TrainingTabFixture.program("Push Pull Legs", id: "ppl"),
            TrainingTabFixture.program("Upper Lower", id: "ul")
        ])

        #expect(screen.presenter.nonActiveTrainingPrograms.map(\.id) == ["ppl", "ul"])
    }

    /// The `onAppear`/`onDisappear` cases were declared with the screen but it had no hooks to
    /// send them, so this was the one screen absent from screen views entirely.
    @Test("Test The Screen Reports Itself As A Screen View")
    func testTheScreenReportsItselfAsAScreenView() {
        let screen = makeScreen()

        screen.presenter.onViewAppear()
        screen.presenter.onViewDisappear()

        #expect(screen.interactor.trackedScreenEventNames == ["TrainingProgramLibraryView_Appear"])
        #expect(screen.interactor.trackedEventNames == ["TrainingProgramLibraryView_Disappear"])
    }

    @Test("Test Deleting A Program Removes It And Is Reported")
    func testDeletingAProgramRemovesItAndIsReported() async {
        let screen = makeScreen()

        await screen.presenter.deleteProgram(TrainingTabFixture.program("Upper Lower", id: "ul"))

        #expect(screen.interactor.deletedProgramIds == ["ul"])
        #expect(screen.interactor.trackedEventNames == [
            "TrainingProgramLibraryView_DeleteProgram_Start",
            "TrainingProgramLibraryView_DeleteProgram_Success"
        ])
    }

    /// A delete that fails is logged as a failure rather than a success, so a program that is still
    /// there is not reported as gone.
    @Test("Test A Failed Delete Is Reported As A Failure")
    func testAFailedDeleteIsReportedAsAFailure() async {
        let screen = makeScreen()
        screen.interactor.deleteError = TrainingTabTestError.failed

        await screen.presenter.deleteProgram(TrainingTabFixture.program("Upper Lower", id: "ul"))

        #expect(screen.interactor.deletedProgramIds.isEmpty)
        #expect(screen.interactor.trackedEventNames == [
            "TrainingProgramLibraryView_DeleteProgram_Start",
            "TrainingProgramLibraryView_DeleteProgram_Fail"
        ])
        // And reported to the user: the program is still in the list, so the confirmed delete
        // otherwise reads as having done nothing.
        #expect(screen.router.alertTitles == ["Unable to delete program"])
    }

    /// Swiping a saved program asks first, and the question does not talk about scheduled workouts
    /// that only the active program has.
    @Test("Test Deleting A Saved Program Asks With Saved Program Copy")
    func testDeletingASavedProgramAsksWithSavedProgramCopy() {
        let push = TrainingTabFixture.program("Push Pull Legs", id: "ppl")
        let upper = TrainingTabFixture.program("Upper Lower", id: "ul")
        let screen = makeScreen(programs: [push, upper], active: push)

        screen.presenter.showDeleteAlert(program: upper)
        screen.presenter.showDeleteAlert(program: push)

        #expect(screen.router.alertTitles == ["Delete Program", "Delete Program"])
        #expect(screen.router.alertSubtitles.first == "Delete 'Upper Lower'? This can't be undone.")
        #expect(screen.router.alertSubtitles.last??.contains("active program") == true)
        #expect(screen.interactor.deletedProgramIds.isEmpty)
    }

    @Test("Test Pressing A Saved Program Opens That Program For Editing")
    func testPressingASavedProgramOpensThatProgramForEditing() {
        let screen = makeScreen()

        screen.presenter.onSavedProgramPressed(TrainingTabFixture.program("Upper Lower", id: "ul"))

        #expect(screen.router.editDelegates.first?.program.id == "ul")
    }

    @Test("Test Creating A Program Opens The Builder")
    func testCreatingAProgramOpensTheBuilder() {
        let screen = makeScreen()

        screen.presenter.onCreateProgramPressed()

        #expect(screen.router.shown == ["createProgram"])
    }
}

// MARK: - Workout library and the program rows

/// The workout library list, which is only a door: pressing a workout opens its detail, and the
/// detail is handed a callback that opens the tracker once the workout is actually started.
@MainActor
struct TrainingWorkoutsLibraryPresenterTests {

    private final class Interactor: SpyGlobalInteractor, WorkoutsInteractor { }

    private final class Router: WorkoutsRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var shown: [String] = []
        private(set) var detailDelegates: [WorkoutTemplateDetailDelegate] = []

        func showWorkoutTrackerView() { shown.append("tracker") }

        func showWorkoutTemplateDetailView(delegate: WorkoutTemplateDetailDelegate) {
            shown.append("templateDetail")
            detailDelegates.append(delegate)
        }
    }

    /// A workout opened from the library belongs to no program, so it must not be attributed to
    /// one — that would credit it to whatever program the user happens to be running.
    @Test("Test A Library Workout Opens Detached From Any Program")
    func testALibraryWorkoutOpensDetachedFromAnyProgram() {
        let router = Router()
        let presenter = WorkoutsPresenter(interactor: Interactor(), router: router)

        presenter.onWorkoutPressed(workout: TrainingTabFixture.template("Push"))

        #expect(router.detailDelegates.first?.workoutTemplate.name == "Push")
        #expect(router.detailDelegates.first?.trainingProgramId == nil)
        #expect(router.detailDelegates.first?.isDeloadCycle == false)
    }

    @Test("Test Starting The Opened Workout Shows The Tracker")
    func testStartingTheOpenedWorkoutShowsTheTracker() async {
        let router = Router()
        let presenter = WorkoutsPresenter(interactor: Interactor(), router: router)
        presenter.onWorkoutPressed(workout: TrainingTabFixture.template("Push"))

        router.detailDelegates.first?.onStartWorkoutPressed?()
        await TestManagers.eventually { router.shown.contains("tracker") }

        #expect(router.shown == ["templateDetail", "tracker"])
    }
}

/// A row in the list of programs the user is not currently running.
@MainActor
struct TrainingProgramGroupPresenterTests {

    private final class Interactor: SpyGlobalInteractor, TrainingProgramDisclosureGroupInteractor { }

    private final class Router: TrainingProgramDisclosureGroupRouter {
        func showShareToFollowerView(delegate: ShareToFollowerDelegate) { }
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var editDelegates: [EditTrainingProgramDelegate] = []

        func showEditTrainingProgramView(delegate: EditTrainingProgramDelegate) { editDelegates.append(delegate) }
    }

    /// The row expands to show a program's days, and pressing it opens that same program — not
    /// whichever one the list last handled.
    @Test("Test Pressing The Row Opens Its Own Program")
    func testPressingTheRowOpensItsOwnProgram() {
        let router = Router()
        let presenter = TrainingProgramDisclosureGroupPresenter(interactor: Interactor(), router: router)

        presenter.onSavedProgramPressed(TrainingTabFixture.program("Upper Lower", id: "ul"))

        #expect(router.editDelegates.first?.program.id == "ul")
    }

    @Test("Test Appearing And Leaving Are Both Tracked")
    func testAppearingAndLeavingAreBothTracked() {
        let interactor = Interactor()
        let presenter = TrainingProgramDisclosureGroupPresenter(interactor: interactor, router: Router())
        let delegate = TrainingProgramDisclosureGroupDelegate(
            trainingProgram: TrainingTabFixture.program("Upper Lower", id: "ul")
        )

        presenter.onViewAppear(delegate: delegate)
        presenter.onViewDisappear(delegate: delegate)

        #expect(interactor.trackedScreenEventNames == ["TrainingProgramDisclosureGroupView_Appear"])
        #expect(interactor.trackedEventNames == ["TrainingProgramDisclosureGroupView_Disappear"])
    }
}

/// The section listing programs the user is not running. It owns no data of its own — the rows do —
/// so all it is answerable for is reporting that it was seen.
@MainActor
struct TrainingInactiveProgramPresenterTests {

    private final class Interactor: SpyGlobalInteractor, InactiveTrainingProgramInteractor { }

    private final class Router: InactiveTrainingProgramRouter {
        let router: AnyRouter = TestRouting.anyRouter
    }

    @Test("Test Appearing And Leaving Are Both Tracked")
    func testAppearingAndLeavingAreBothTracked() {
        let interactor = Interactor()
        let presenter = InactiveTrainingProgramPresenter(interactor: interactor, router: Router())
        let delegate = InactiveTrainingProgramDelegate(inactivePrograms: [
            TrainingTabFixture.program("Upper Lower", id: "ul")
        ])

        presenter.onViewAppear(delegate: delegate)
        presenter.onViewDisappear(delegate: delegate)

        #expect(interactor.trackedScreenEventNames == ["InactiveTrainingProgramView_Appear"])
        #expect(interactor.trackedEventNames == ["InactiveTrainingProgramView_Disappear"])
    }
}
