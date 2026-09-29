//
//  TrainingHomePresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

enum TrainingTabTestError: Error { case failed }

/// A fixed Wednesday in March, deliberately not today: anything that reaches for the current date
/// instead of the day it was handed then fails rather than passing by coincidence.
@MainActor
enum TrainingTabFixture {
    static let calendar = Calendar.current

    static func date(month: Int = 3, day: Int, hour: Int = 9, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute)) ?? .distantPast
    }

    static func exercise(_ name: String, muscles: [Muscles: MuscleTargetType] = [:]) -> ExerciseModel {
        ExerciseModel(
            id: name.lowercased(),
            authorId: "author-1",
            name: name,
            trackableMetrics: [.reps],
            type: nil,
            laterality: nil,
            muscleGroups: muscles,
            isBodyweight: false,
            rangeOfMotion: 0,
            stability: 0,
            bodyWeightContribution: 0,
            alternateNames: []
        )
    }

    static func template(_ name: String) -> WorkoutTemplateModel {
        WorkoutTemplateModel(id: name.lowercased(), authorId: "author-1", name: name)
    }

    static func program(_ name: String, id: String) -> TrainingProgram {
        TrainingProgram(id: id, authorId: "author-1", name: name, icon: "dumbbell", colour: "#FF0000")
    }

    /// A finished session unless `endedAt` is cleared — most screens here only count finished work.
    static func session(
        id: String,
        name: String = "Upper",
        on date: Date,
        finished: Bool = true,
        isRestDay: Bool = false
    ) -> WorkoutSessionModel {
        WorkoutSessionModel(
            id: id,
            authorId: "author-1",
            name: name,
            dateCreated: date,
            endedAt: finished ? date.addingTimeInterval(3600) : nil,
            exercises: [],
            isRestDay: isRestDay
        )
    }
}

// MARK: - Training tab root

/// The Training tab's root: the calendar strip of what has been logged, the shortcut into an empty
/// workout, and the doors to the program, workout and history libraries.
///
/// The risk is the calendar. Markers are built in one pass keyed by day, so anything keyed on the
/// raw logged timestamp would give every session its own cell, and the program pre-creates rest
/// days for dates that have not arrived — those must not appear as already done.
///
/// `showAlert(...)`, `showSimpleAlert(...)` and `dismissScreen()` come from a `GlobalRouter`
/// protocol extension, so a double can never see them. Where the screen's answer is an alert, these
/// tests assert that nothing else happened instead.
@MainActor
struct TrainingHomePresenterTests {

    private final class Interactor: SpyGlobalInteractor, TrainingInteractor {
        var currentUser: UserModel?
        var userImageUrl: String?
        var activeTrainingProgram: TrainingProgram?
        var activeSession: WorkoutSessionModel?
        var workoutSessions: [WorkoutSessionModel] = []
        var favouriteGymProfile: GymProfileModel?
        var startWorkoutError: Error?
        private(set) var startedTemplateNames: [String] = []
        private(set) var blankWorkoutStarts = 0
        private(set) var didDeleteActiveSession = false

        func getAuthId() throws -> String { "author-1" }

        func getWorkoutTemplate(id: String) async throws -> WorkoutTemplateModel {
            TrainingTabFixture.template(id)
        }

        func updateActiveSession(_ session: WorkoutSessionModel) throws { activeSession = session }

        func saveWorkoutSession(_ session: WorkoutSessionModel) async throws { }

        func startWorkout(for template: WorkoutTemplateModel, in trainingProgramId: String?) async throws {
            if let startWorkoutError { throw startWorkoutError }
            startedTemplateNames.append(template.name)
        }

        func startBlankWorkout() async throws {
            if let startWorkoutError { throw startWorkoutError }
            blankWorkoutStarts += 1
        }

        func deleteActiveSession() throws {
            didDeleteActiveSession = true
            activeSession = nil
        }

        func getPreference(templateId: String) -> ExerciseUnitPreference {
            ExerciseUnitPreference(exerciseModelId: templateId)
        }
    }

    /// `showDevSettingsView()` is declared unguarded: the protocol wraps it in `#if DEV || MOCK`
    /// but the test target builds without those flags.
    private final class Router: TrainingRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var shown: [String] = []
        private(set) var alertTitles: [String] = []

        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) {
            alertTitles.append(title)
        }
        private(set) var sessionDetailDelegates: [WorkoutSessionDetailDelegate] = []
        private(set) var addTrainingDelegates: [AddTrainingDelegate] = []
        private(set) var createWorkoutDelegates: [CreateWorkoutDelegate] = []

        func showDevSettingsView() { shown.append("devSettings") }
        func showTrainingProgramLibraryView() { shown.append("programLibrary") }
        func showWorkoutsView(delegate: WorkoutsDelegate) { shown.append("workouts") }
        func showWorkoutHistoryView() { shown.append("history") }
        func showWorkoutTemplateDetailView(delegate: WorkoutTemplateDetailDelegate) { shown.append("templateDetail") }
        func showWorkoutTrackerView() { shown.append("tracker") }
        func showCreateExerciseView() { shown.append("createExercise") }
        func showProfileViewZoom(transitionId: String?, namespace: Namespace.ID) { shown.append("profile") }
        func showEditTrainingProgramView(delegate: EditTrainingProgramDelegate) { shown.append("editProgram") }

        func showWorkoutSessionDetailView(delegate: WorkoutSessionDetailDelegate) {
            shown.append("sessionDetail")
            sessionDetailDelegates.append(delegate)
        }

        func showAddTrainingView(delegate: AddTrainingDelegate, onDismiss: (() -> Void)?) {
            shown.append("addTraining")
            addTrainingDelegates.append(delegate)
        }

        func showCreateProgramView(delegate: CreateProgramDelegate) { shown.append("createProgram") }

        func showCreateWorkoutView(delegate: CreateWorkoutDelegate) {
            shown.append("createWorkout")
            createWorkoutDelegates.append(delegate)
        }
    }

    private struct Screen {
        let presenter: TrainingPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen(sessions: [WorkoutSessionModel] = [], active: WorkoutSessionModel? = nil) -> Screen {
        let interactor = Interactor()
        interactor.workoutSessions = sessions
        interactor.activeSession = active
        let router = Router()
        return Screen(
            presenter: TrainingPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    // MARK: - Calendar markers

    /// Two workouts on one day are one cell showing two, not two cells. A marker keyed on the
    /// logged time rather than the day would give each its own key and the strip would never
    /// badge anything.
    @Test("Test Two Workouts On One Day Are One Marker")
    func testTwoWorkoutsOnOneDayAreOneMarker() {
        let morning = TrainingTabFixture.date(day: 11, hour: 7)
        let evening = TrainingTabFixture.date(day: 11, hour: 19)
        let screen = makeScreen(sessions: [
            TrainingTabFixture.session(id: "s1", on: morning),
            TrainingTabFixture.session(id: "s2", on: evening)
        ])

        let markers = screen.presenter.loggedWorkoutMarkersByDay()

        #expect(markers.count == 1)
        #expect(markers[TrainingTabFixture.calendar.startOfDay(for: morning)] == .count(2))
    }

    @Test("Test Separate Days Get Separate Markers")
    func testSeparateDaysGetSeparateMarkers() {
        let wednesday = TrainingTabFixture.date(day: 11)
        let friday = TrainingTabFixture.date(day: 13)
        let screen = makeScreen(sessions: [
            TrainingTabFixture.session(id: "s1", on: wednesday),
            TrainingTabFixture.session(id: "s2", on: friday)
        ])

        let markers = screen.presenter.loggedWorkoutMarkersByDay()

        #expect(markers[TrainingTabFixture.calendar.startOfDay(for: wednesday)] == .count(1))
        #expect(markers[TrainingTabFixture.calendar.startOfDay(for: friday)] == .count(1))
    }

    /// A workout still in progress has not been logged yet, so it must not tick its day.
    @Test("Test A Workout Still Running Is Not Marked")
    func testAWorkoutStillRunningIsNotMarked() {
        let screen = makeScreen(sessions: [
            TrainingTabFixture.session(id: "s1", on: TrainingTabFixture.date(day: 11), finished: false)
        ])

        #expect(screen.presenter.loggedWorkoutMarkersByDay().isEmpty)
    }

    /// A program pre-creates its rest days for dates ahead of today. Marking them would tell the
    /// user they had already rested on a day that has not happened.
    @Test("Test A Rest Day Yet To Come Is Not Marked")
    func testARestDayYetToComeIsNotMarked() {
        let tomorrow = Date().addingTimeInterval(86_400)
        let screen = makeScreen(sessions: [
            TrainingTabFixture.session(id: "rest", name: "Rest", on: tomorrow, isRestDay: true)
        ])

        #expect(screen.presenter.loggedWorkoutMarkersByDay().isEmpty)
    }

    @Test("Test A Rest Day Already Taken Is Marked")
    func testARestDayAlreadyTakenIsMarked() {
        let past = TrainingTabFixture.date(day: 11)
        let screen = makeScreen(sessions: [
            TrainingTabFixture.session(id: "rest", name: "Rest", on: past, isRestDay: true)
        ])

        #expect(screen.presenter.loggedWorkoutMarkersByDay()[TrainingTabFixture.calendar.startOfDay(for: past)] == .count(1))
    }

    // MARK: - Tapping a day

    @Test("Test Tapping A Day With One Workout Opens It")
    func testTappingADayWithOneWorkoutOpensIt() {
        let day = TrainingTabFixture.date(day: 11)
        let screen = makeScreen(sessions: [TrainingTabFixture.session(id: "s1", name: "Push", on: day)])

        screen.presenter.onDatePressed(date: day)

        #expect(screen.router.shown == ["sessionDetail"])
        #expect(screen.router.sessionDetailDelegates.first?.initialSession.id == "s1")
        #expect(screen.interactor.trackedEventNames == [
            "TrainingView_OpenCompletedSession_Start",
            "TrainingView_OpenCompletedSession_Success"
        ])
    }

    /// The day tapped is the day opened. A session on a different date must not answer for it.
    @Test("Test Tapping An Empty Day Opens Nothing")
    func testTappingAnEmptyDayOpensNothing() {
        let screen = makeScreen(sessions: [
            TrainingTabFixture.session(id: "s1", on: TrainingTabFixture.date(day: 11))
        ])

        screen.presenter.onDatePressed(date: TrainingTabFixture.date(day: 12))

        #expect(screen.router.shown.isEmpty)
        #expect(screen.interactor.trackedEventNames.isEmpty)
    }

    /// Two workouts on the day means a choice, so nothing opens until the user picks one. The
    /// picker is a `GlobalRouter` alert, so the assertion is that no screen was pushed.
    @Test("Test Tapping A Day With Two Workouts Opens Neither")
    func testTappingADayWithTwoWorkoutsOpensNeither() {
        let day = TrainingTabFixture.date(day: 11)
        let screen = makeScreen(sessions: [
            TrainingTabFixture.session(id: "s1", on: day, finished: true),
            TrainingTabFixture.session(id: "s2", on: TrainingTabFixture.date(day: 11, hour: 18))
        ])

        screen.presenter.onDatePressed(date: day)

        #expect(screen.router.shown.isEmpty)
        #expect(screen.interactor.trackedEventNames.isEmpty)
    }

    @Test("Test Tapping A Day Whose Workout Is Unfinished Opens Nothing")
    func testTappingADayWhoseWorkoutIsUnfinishedOpensNothing() {
        let day = TrainingTabFixture.date(day: 11)
        let screen = makeScreen(sessions: [TrainingTabFixture.session(id: "s1", on: day, finished: false)])

        screen.presenter.onDatePressed(date: day)

        #expect(screen.router.shown.isEmpty)
    }

    // MARK: - Starting an empty workout

    /// "Start Empty Workout" used to run the template wizard and save a template. It now starts a
    /// blank session and opens the tracker, which adds exercises as it goes.
    @Test("Test Starting An Empty Workout Opens The Tracker On A Blank Session")
    func testStartingAnEmptyWorkoutOpensTheTrackerOnABlankSession() async {
        let screen = makeScreen()

        screen.presenter.onStartEmptyWorkoutPressed()

        #expect(await TestManagers.eventually { screen.router.shown == ["tracker"] })
        #expect(screen.interactor.blankWorkoutStarts == 1)
        #expect(screen.interactor.startedTemplateNames.isEmpty)
    }

    /// With a workout already running, starting another asks what to do with the live one rather
    /// than silently replacing it — so nothing is started and the tracker does not open.
    @Test("Test Starting While One Is Running Asks First")
    func testStartingWhileOneIsRunningAsksFirst() async {
        let live = TrainingTabFixture.session(id: "live", on: TrainingTabFixture.date(day: 11), finished: false)
        let screen = makeScreen(active: live)

        screen.presenter.onStartEmptyWorkoutPressed()
        try? await Task.sleep(for: .milliseconds(150))

        #expect(screen.router.alertTitles == ["Active Workout"])
        #expect(screen.interactor.blankWorkoutStarts == 0)
        #expect(screen.router.shown.isEmpty)
        #expect(!screen.interactor.didDeleteActiveSession)
    }

    /// A workout that cannot be started leaves the user where they were with an explanation rather
    /// than pushing them into an empty tracker.
    @Test("Test A Workout That Fails To Start Does Not Open The Tracker")
    func testAWorkoutThatFailsToStartDoesNotOpenTheTracker() async {
        let screen = makeScreen()
        screen.interactor.startWorkoutError = TrainingTabTestError.failed

        screen.presenter.onStartEmptyWorkoutPressed()
        try? await Task.sleep(for: .milliseconds(150))

        #expect(!screen.router.shown.contains("tracker"))
    }

    // MARK: - The add menu and the libraries

    @Test("Test The Add Menu Offers A Program A Workout And An Exercise")
    func testTheAddMenuOffersAProgramAWorkoutAndAnExercise() {
        let screen = makeScreen()

        screen.presenter.onAddPressed()
        let delegate = screen.router.addTrainingDelegates.first
        delegate?.onSelectProgram?()
        delegate?.onSelectWorkout?()
        delegate?.onSelectExercise?()

        #expect(screen.router.shown == ["addTraining", "createProgram", "createWorkout", "createExercise"])
    }

    @Test("Test Each Library Door Opens Its Own Screen")
    func testEachLibraryDoorOpensItsOwnScreen() {
        let screen = makeScreen()

        screen.presenter.onTrainingProgramLibraryView()
        screen.presenter.onChooseProgramPressed()
        screen.presenter.onWorkoutLibraryPressed()
        screen.presenter.onWorkoutHistoryPressed()

        #expect(screen.router.shown == ["programLibrary", "programLibrary", "workouts", "history"])
    }

    @Test("Test Appearing And Leaving Are Both Tracked")
    func testAppearingAndLeavingAreBothTracked() {
        let screen = makeScreen()

        screen.presenter.onViewAppear(delegate: TrainingDelegate())
        screen.presenter.onViewDisappear(delegate: TrainingDelegate())

        #expect(screen.interactor.trackedScreenEventNames == ["TrainingView_Appear"])
        #expect(screen.interactor.trackedEventNames == ["TrainingView_Disappear"])
    }
}

// MARK: - Workout template detail

/// One saved workout: the muscles it targets, starting it, editing it and deleting it.
///
/// The muscle summary is the derived state worth pinning. Set counts are weighted — a muscle the
/// exercise only assists counts half — and the same muscle is summed across exercises, so a screen
/// claiming "12 sets for chest" has to be arithmetic rather than a row count.
@MainActor
struct TrainingTemplateDetailPresenterTests {

    private final class Interactor: SpyGlobalInteractor, WorkoutTemplateDetailInteractor {
        var currentUser: UserModel?
        var activeSession: WorkoutSessionModel?
        var startWorkoutError: Error?
        var deleteError: Error?
        var sessionAfterStart: WorkoutSessionModel?
        private(set) var startedIn: [String?] = []
        private(set) var updatedSessions: [WorkoutSessionModel] = []
        private(set) var deletedTemplateIds: [String] = []
        private(set) var didDeleteActiveSession = false

        func startWorkout(for template: WorkoutTemplateModel, in trainingProgramId: String?) async throws {
            if let startWorkoutError { throw startWorkoutError }
            startedIn.append(trainingProgramId)
            activeSession = sessionAfterStart
        }

        func updateActiveSession(_ session: WorkoutSessionModel) throws { updatedSessions.append(session) }

        func deleteActiveSession() throws {
            didDeleteActiveSession = true
            activeSession = nil
        }

        func deleteWorkoutTemplate(id: String) async throws {
            if let deleteError { throw deleteError }
            deletedTemplateIds.append(id)
        }

        func getPreference(templateId: String) -> ExerciseUnitPreference {
            ExerciseUnitPreference(exerciseModelId: templateId)
        }
    }

    private final class Router: WorkoutTemplateDetailRouter {
        func showShareToFollowerView(delegate: ShareToFollowerDelegate) { }
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var shown: [String] = []
        private(set) var exerciseDetailDelegates: [ExerciseModelDetailDelegate] = []
        private(set) var createWorkoutDelegates: [CreateWorkoutDelegate] = []

        func showDevSettingsView() { shown.append("devSettings") }
        func showWorkoutTrackerView() { shown.append("tracker") }

        func showCreateWorkoutView(delegate: CreateWorkoutDelegate) {
            shown.append("createWorkout")
            createWorkoutDelegates.append(delegate)
        }

        func showExerciseModelDetailView(delegate: ExerciseModelDetailDelegate) {
            shown.append("exerciseDetail")
            exerciseDetailDelegates.append(delegate)
        }
    }

    private struct Screen {
        let presenter: WorkoutTemplateDetailPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen(active: WorkoutSessionModel? = nil) -> Screen {
        let interactor = Interactor()
        interactor.activeSession = active
        let router = Router()
        return Screen(
            presenter: WorkoutTemplateDetailPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    private func entry(_ name: String, muscles: [Muscles: MuscleTargetType], sets: Int) -> WorkoutTemplateExercise {
        WorkoutTemplateExercise(
            exercise: TrainingTabFixture.exercise(name, muscles: muscles),
            setTargets: (1...max(sets, 1)).prefix(sets).map { SetTarget(setNumber: $0) },
            setRestTimers: false
        )
    }

    // MARK: - Target muscles

    /// A muscle the exercise only assists earns half a set, because three sets of bench press is
    /// not three sets of triceps work.
    @Test("Test An Assisting Muscle Counts For Half A Set")
    func testAnAssistingMuscleCountsForHalfASet() {
        let screen = makeScreen()
        let bench = entry("Bench", muscles: [.chest: .primary, .triceps: .secondary], sets: 3)

        let summaries = screen.presenter.targetMuscleSummaries(exercises: [bench])

        #expect(summaries.map(\.muscle) == [.chest, .triceps])
        #expect(summaries.first?.weightedTargetSets == 3.0)
        #expect(summaries.last?.weightedTargetSets == 1.5)
    }

    @Test("Test One Muscle Sums Across Every Exercise That Hits It")
    func testOneMuscleSumsAcrossEveryExerciseThatHitsIt() {
        let screen = makeScreen()
        let exercises = [
            entry("Bench", muscles: [.chest: .primary], sets: 3),
            entry("Fly", muscles: [.chest: .primary], sets: 2)
        ]

        let summaries = screen.presenter.targetMuscleSummaries(exercises: exercises)

        #expect(summaries.count == 1)
        #expect(summaries.first?.weightedTargetSets == 5.0)
        #expect(summaries.first?.exerciseCount == 2)
    }

    /// Ordering is by muscle name so the same workout always reads the same way — a dictionary
    /// walked in its own order would reshuffle the list between openings.
    @Test("Test Muscles Are Listed Alphabetically")
    func testMusclesAreListedAlphabetically() {
        let screen = makeScreen()
        let exercises = [
            entry("Squat", muscles: [.quads: .primary, .glutes: .primary, .abs: .secondary], sets: 3)
        ]

        let summaries = screen.presenter.targetMuscleSummaries(exercises: exercises)

        #expect(summaries.map(\.muscle.name) == ["Abs", "Glutes", "Quads"])
    }

    /// An exercise nobody has given a set target to contributes nothing, rather than counting as a
    /// muscle worked zero times.
    @Test("Test An Exercise With No Set Targets Is Left Out")
    func testAnExerciseWithNoSetTargetsIsLeftOut() {
        let screen = makeScreen()
        let placeholder = WorkoutTemplateExercise(
            exercise: TrainingTabFixture.exercise("Curl", muscles: [.biceps: .primary]),
            setTargets: [],
            setRestTimers: false
        )

        #expect(screen.presenter.targetMuscleSummaries(exercises: [placeholder]).isEmpty)
    }

    @Test("Test An Empty Workout Targets Nothing")
    func testAnEmptyWorkoutTargetsNothing() {
        let screen = makeScreen()

        #expect(screen.presenter.targetMuscleSummaries(exercises: []).isEmpty)
    }

    /// Whole set counts read as whole numbers; a half set earned from an assisting muscle keeps
    /// its decimal rather than being rounded away.
    @Test("Test Half Sets Keep Their Decimal And Whole Sets Do Not")
    func testHalfSetsKeepTheirDecimalAndWholeSetsDoNot() {
        let screen = makeScreen()

        #expect(screen.presenter.formattedSetCount(3.0) == "3")
        #expect(screen.presenter.formattedSetCount(1.5) == "1.5")
        #expect(screen.presenter.formattedSetCount(0) == "0")
    }

    // MARK: - Starting the workout

    @Test("Test Starting The Workout Runs It Against Its Program")
    func testStartingTheWorkoutRunsItAgainstItsProgram() async {
        let screen = makeScreen()

        screen.presenter.onStartWorkoutPressed(
            onStartWorkout: nil,
            workoutTemplate: TrainingTabFixture.template("Push"),
            trainingProgramId: "program-1"
        )
        await TestManagers.eventually { !screen.interactor.startedIn.isEmpty }

        #expect(screen.interactor.startedIn == ["program-1"])
    }

    /// A deload week starts from lighter numbers, so the session is rewritten the moment it is
    /// created rather than leaving the user to drop every weight by hand.
    @Test("Test A Deload Week Rewrites The Session It Just Started")
    func testADeloadWeekRewritesTheSessionItJustStarted() async {
        let screen = makeScreen()
        screen.interactor.sessionAfterStart = TrainingTabFixture.session(
            id: "live",
            on: TrainingTabFixture.date(day: 11),
            finished: false
        )

        screen.presenter.onStartWorkoutPressed(
            onStartWorkout: nil,
            workoutTemplate: TrainingTabFixture.template("Push"),
            trainingProgramId: "program-1",
            isDeloadCycle: true
        )
        await TestManagers.eventually { !screen.interactor.updatedSessions.isEmpty }

        #expect(screen.interactor.updatedSessions.count == 1)
    }

    @Test("Test An Ordinary Week Leaves The Session Alone")
    func testAnOrdinaryWeekLeavesTheSessionAlone() async {
        let screen = makeScreen()
        screen.interactor.sessionAfterStart = TrainingTabFixture.session(
            id: "live",
            on: TrainingTabFixture.date(day: 11),
            finished: false
        )

        screen.presenter.onStartWorkoutPressed(
            onStartWorkout: nil,
            workoutTemplate: TrainingTabFixture.template("Push"),
            trainingProgramId: nil
        )
        await TestManagers.eventually { !screen.interactor.startedIn.isEmpty }
        try? await Task.sleep(for: .milliseconds(100))

        #expect(screen.interactor.updatedSessions.isEmpty)
    }

    /// A workout already in progress is the user's unsaved work, so starting another asks first
    /// and discards nothing until they answer.
    @Test("Test A Running Workout Is Not Discarded Without Asking")
    func testARunningWorkoutIsNotDiscardedWithoutAsking() async {
        let live = TrainingTabFixture.session(id: "live", on: TrainingTabFixture.date(day: 11), finished: false)
        let screen = makeScreen(active: live)

        screen.presenter.onStartWorkoutPressed(
            onStartWorkout: nil,
            workoutTemplate: TrainingTabFixture.template("Push"),
            trainingProgramId: nil
        )
        try? await Task.sleep(for: .milliseconds(150))

        #expect(screen.interactor.startedIn.isEmpty)
        #expect(!screen.interactor.didDeleteActiveSession)
        #expect(screen.router.shown.isEmpty)
    }

    // MARK: - Deleting

    @Test("Test Deleting The Workout Removes It And Leaves The Screen")
    func testDeletingTheWorkoutRemovesItAndLeavesTheScreen() async {
        let screen = makeScreen()
        var dismissed = false

        await screen.presenter.deleteWorkout(template: TrainingTabFixture.template("Push"), onDismiss: { dismissed = true })

        #expect(screen.interactor.deletedTemplateIds == ["push"])
        #expect(dismissed)
    }

    /// A delete that fails keeps the user on the workout, with the spinner cleared so they can try
    /// again — leaving it spinning would strand them on a screen that looks busy forever.
    @Test("Test A Failed Delete Keeps The Workout And Clears The Spinner")
    func testAFailedDeleteKeepsTheWorkoutAndClearsTheSpinner() async {
        let screen = makeScreen()
        screen.interactor.deleteError = TrainingTabTestError.failed
        var dismissed = false

        await screen.presenter.deleteWorkout(template: TrainingTabFixture.template("Push"), onDismiss: { dismissed = true })

        #expect(!dismissed)
        #expect(!screen.presenter.isDeleting)
    }

    // MARK: - Rows

    @Test("Test Pressing An Exercise Opens Its Own Detail")
    func testPressingAnExerciseOpensItsOwnDetail() {
        let screen = makeScreen()

        screen.presenter.onExercisePressed(TrainingTabFixture.exercise("Bench"))

        #expect(screen.router.exerciseDetailDelegates.first?.exerciseModel.name == "Bench")
        #expect(screen.interactor.trackedEventNames == ["WorkoutTemplateDetailView_Exercise_Press"])
    }

    /// Editing opens the builder on this workout rather than a blank one.
    @Test("Test Editing Opens The Builder On This Workout")
    func testEditingOpensTheBuilderOnThisWorkout() {
        let screen = makeScreen()

        screen.presenter.onEditWorkoutPressed(template: TrainingTabFixture.template("Push"))

        #expect(screen.router.createWorkoutDelegates.first?.workoutTemplate?.name == "Push")
    }
}
