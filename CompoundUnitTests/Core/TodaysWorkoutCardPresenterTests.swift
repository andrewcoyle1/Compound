//
//  TodaysWorkoutCardPresenterTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

/// Today's workout card: Start goes straight into the tracker, and a deload microcycle's weight
/// cut is applied however the workout is started.
@MainActor
struct TodaysWorkoutCardPresenterTests {

    private final class Interactor: SpyGlobalInteractor, TodaysWorkoutCardInteractor {
        var activeMesocycle: Mesocycle?
        var activeMesocycleRun: MesocycleSchedule.Run?
        var workoutSessions: [WorkoutSessionModel] = []
        var activeSession: WorkoutSessionModel?
        private(set) var startedTemplateIds: [String] = []
        private(set) var startedMicrocycles: [Int?] = []
        private(set) var plannedMicrocycles: [Int?] = []
        var startError: Error?

        func skipScheduledWorkout(_ slot: MesocycleSchedule.Slot) async throws { }

        func deleteActiveSession() throws { activeSession = nil }

        var currentUser: UserModel? = UserModel(userId: "author-1")
        var preferences: [String: ExerciseUnitPreference] = [:]
        /// What the planned session's exercises are; one 100 kg × 8 bench press by default.
        var plannedExercises: [WorkoutExerciseModel] = [WorkoutExerciseModel(
            id: "e1",
            authorId: "author-1",
            templateId: "ex",
            name: "Bench Press",
            trackingMode: .weightReps,
            index: 1,
            sets: [WorkoutSetModel(id: "s1", authorId: "author-1", index: 1, reps: 8, weightKg: 100, isWarmup: false, dateCreated: Date())]
        )]

        func getPreference(templateId: String) -> ExerciseUnitPreference {
            preferences[templateId] ?? ExerciseUnitPreference(exerciseModelId: templateId)
        }

        func plannedSession(for template: WorkoutTemplateModel, in mesocycleId: String?, microcycleIndex: Int?) async throws -> WorkoutSessionModel {
            if let startError { throw startError }
            plannedMicrocycles.append(microcycleIndex)
            return WorkoutSessionModel(
                id: "started",
                authorId: "author-1",
                name: template.name,
                workoutTemplateId: template.id,
                mesocycleId: mesocycleId,
                dateCreated: Date(),
                exercises: plannedExercises
            )
        }

        func startWorkout(for template: WorkoutTemplateModel, in mesocycleId: String?, microcycleIndex: Int?) async throws {
            activeSession = try await plannedSession(for: template, in: mesocycleId, microcycleIndex: microcycleIndex)
            startedTemplateIds.append(template.id)
            startedMicrocycles.append(microcycleIndex)
        }

        func updateActiveSession(_ session: WorkoutSessionModel) throws {
            activeSession = session
        }
    }

    private final class Router: TodaysWorkoutCardRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var shown: [String] = []
        private(set) var detailDelegates: [WorkoutTemplateDetailDelegate] = []
        private(set) var dialogTitles: [String] = []

        func showWorkoutTrackerView() { shown.append("tracker") }
        func showWorkoutTemplateDetailView(delegate: WorkoutTemplateDetailDelegate) {
            shown.append("templateDetail")
            detailDelegates.append(delegate)
        }
        private(set) var openedSessionIds: [String] = []
        func showWorkoutSessionDetailView(delegate: WorkoutSessionDetailDelegate) {
            shown.append("sessionDetail")
            openedSessionIds.append(delegate.initialSession.id)
        }
        func showConfirmationDialog(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) {
            dialogTitles.append(title)
        }
        func showSimpleAlert(title: String, subtitle: String?) { shown.append("alert") }
    }

    private let day = WorkoutTemplateModel(
        id: "push",
        authorId: "author-1",
        name: "Push",
        exercises: [WorkoutTemplateExercise(exercise: .mock, setRestTimers: false)]
    )

    private struct Screen {
        let presenter: TodaysWorkoutCardPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen(deload: DeloadType = .none, cycles: Int = 4, active: WorkoutSessionModel? = nil) -> Screen {
        let mesocycle = Mesocycle(
            id: "meso-1",
            authorId: "author-1",
            name: "Block",
            icon: "dumbbell",
            colour: "#FF0000",
            numMicrocycles: cycles,
            deload: deload,
            periodisation: false,
            workoutTemplates: [day],
            dateCreated: Date(timeIntervalSince1970: 0)
        )
        let interactor = Interactor()
        interactor.activeMesocycle = mesocycle
        interactor.activeMesocycleRun = MesocycleSchedule.Run(mesocycle: mesocycle, startedAt: Date(timeIntervalSince1970: 0))
        interactor.activeSession = active
        let router = Router()
        return Screen(presenter: TodaysWorkoutCardPresenter(interactor: interactor, router: router), interactor: interactor, router: router)
    }

    /// On a rest day the card offers the workout after it, for a user who would rather train.
    @Test("Test A Rest Day Offers The Next Workout")
    func testARestDayOffersTheNextWorkout() async {
        let rest = WorkoutTemplateModel(id: "rest", authorId: "author-1", name: "Rest", exercises: [])
        let pull = WorkoutTemplateModel(id: "pull", authorId: "author-1", name: "Pull", exercises: day.exercises)
        let screen = makeScreen()
        let mesocycle = Mesocycle(
            id: "meso-1", authorId: "author-1", name: "Block", icon: "dumbbell", colour: "#FF0000",
            numMicrocycles: 4, workoutTemplates: [day, rest, pull], dateCreated: Date(timeIntervalSince1970: 0)
        )
        screen.interactor.activeMesocycle = mesocycle
        screen.interactor.activeMesocycleRun = MesocycleSchedule.Run(mesocycle: mesocycle, startedAt: Date(timeIntervalSince1970: 0))
        let yesterday = Date().addingTimeInterval(-86_400)
        let today = Calendar.current.startOfDay(for: Date())
        screen.interactor.workoutSessions = [
            WorkoutSessionModel(authorId: "author-1", name: "Push", workoutTemplateId: "push", mesocycleId: "meso-1",
                                dateCreated: yesterday, endedAt: yesterday, exercises: []),
            WorkoutSessionModel(authorId: "author-1", name: "Rest", workoutTemplateId: "rest", mesocycleId: "meso-1",
                                dateCreated: today, endedAt: today, exercises: [], isRestDay: true)
        ]

        #expect(screen.presenter.isTodayRestDay)
        #expect(screen.presenter.nextWorkoutName == "Pull")
        screen.presenter.onStartPressed()

        #expect(await TestManagers.eventually { screen.interactor.startedTemplateIds == ["pull"] })
    }

    @Test("Test Start Opens The Tracker Without The Preview")
    func testStartOpensTheTrackerWithoutThePreview() async {
        let screen = makeScreen()
        #expect(screen.presenter.canStart)

        screen.presenter.onStartPressed()

        #expect(await TestManagers.eventually { screen.router.shown == ["tracker"] })
        #expect(screen.interactor.startedTemplateIds == ["push"])
        #expect(screen.interactor.activeSession?.exercises[0].sets[0].weightKg == 100)
    }

    /// The first microcycle of a block that deloads at the start is lighter, from Start as from
    /// the Active Mesocycle screen.
    @Test("Test Start In A Deload Microcycle Cuts The Weights")
    func testStartInADeloadMicrocycleCutsTheWeights() async {
        let screen = makeScreen(deload: .start)
        #expect(screen.presenter.isTodayDeload)

        screen.presenter.onStartPressed()

        #expect(await TestManagers.eventually { screen.router.shown == ["tracker"] })
        #expect(screen.interactor.activeSession?.exercises[0].sets[0].weightKg == 65)
    }

    /// Push done yesterday filled the first microcycle, so today's Push is week 2: Start, the
    /// preview and the card's targets all run week 2's targets.
    @Test("Test Today's Workout Runs Its Own Microcycle")
    func testTodaysWorkoutRunsItsOwnMicrocycle() async {
        let screen = makeScreen()
        let yesterday = Date().addingTimeInterval(-86_400)
        screen.interactor.workoutSessions = [
            WorkoutSessionModel(authorId: "author-1", name: "Push", workoutTemplateId: "push", mesocycleId: "meso-1",
                                dateCreated: yesterday, endedAt: yesterday, exercises: [])
        ]

        screen.presenter.onTodaysWorkoutPressed()
        await screen.presenter.loadTargets()
        screen.presenter.onStartPressed()

        #expect(await TestManagers.eventually { screen.interactor.startedMicrocycles == [2] })
        #expect(screen.router.detailDelegates.first?.microcycleIndex == 2)
        #expect(screen.interactor.plannedMicrocycles.first == 2)
    }

    @Test("Test Tapping The Card Passes The Deload To The Preview")
    func testTappingTheCardPassesTheDeloadToThePreview() {
        let screen = makeScreen(deload: .start)

        screen.presenter.onTodaysWorkoutPressed()

        #expect(screen.router.detailDelegates.first?.isDeloadCycle == true)
    }

    @Test("Test Start With A Workout Running Asks First")
    func testStartWithAWorkoutRunningAsksFirst() async throws {
        let running = WorkoutSessionModel(id: "running", authorId: "author-1", name: "Legs", dateCreated: Date(), exercises: [])
        let screen = makeScreen(active: running)

        screen.presenter.onStartPressed()

        #expect(screen.router.dialogTitles == [String(localized: "Active Workout")])
        #expect(screen.interactor.startedTemplateIds.isEmpty)
        #expect(screen.router.shown.isEmpty)
    }

    @Test("Test A Failed Start Says So")
    func testAFailedStartSaysSo() async {
        let screen = makeScreen()
        screen.interactor.startError = URLError(.notConnectedToInternet)

        screen.presenter.onStartPressed()

        #expect(await TestManagers.eventually { screen.router.shown == ["alert"] })
    }

    // MARK: - Before the workout

    private func set(reps: Int? = nil, weightKg: Double? = nil, seconds: Int? = nil, meters: Double? = nil) -> WorkoutSetModel {
        WorkoutSetModel(
            id: UUID().uuidString, authorId: "author-1", index: 1, reps: reps, weightKg: weightKg,
            durationSec: seconds, distanceMeters: meters, isWarmup: false, completedAt: Date(), dateCreated: Date()
        )
    }

    /// Each target reads in the exercise's own units, whatever it tracks.
    @Test("Test A Target Reads In The Exercises Units")
    func testATargetReadsInTheExercisesUnits() {
        let kilograms = ExerciseUnitPreference(exerciseModelId: "x")
        let imperial = ExerciseUnitPreference(exerciseModelId: "x", weightUnit: .pounds, distanceUnit: .miles)
        let detail = TodaysWorkoutCardPresenter.targetDetail

        #expect(detail(set(reps: 8, weightKg: 102.5), .weightReps, kilograms) == "102.5 kg × 8")
        #expect(detail(set(reps: 8, weightKg: 100), .weightReps, imperial) == "220.5 lb × 8")
        #expect(detail(set(reps: 12, weightKg: 0), .weightReps, kilograms) == "12 reps")
        #expect(detail(set(reps: 15), .repsOnly, kilograms) == "15 reps")
        #expect(detail(set(seconds: 90), .timeOnly, kilograms) == "1:30")
        #expect(detail(set(meters: 1_609.34), .distanceTime, imperial) == "1 mi")
        #expect(detail(set(), .weightReps, kilograms) == nil)
        #expect(detail(nil, .weightReps, kilograms) == nil)
    }

    /// The targets are what Start would prefill, cut in a deload week as Start cuts them, and an
    /// exercise with nothing prefilled shows its name alone.
    @Test("Test Targets Are The Trackers Prefill")
    func testTargetsAreTheTrackersPrefill() async {
        let screen = makeScreen(deload: .start)
        screen.interactor.plannedExercises.append(WorkoutExerciseModel(
            id: "e2", authorId: "author-1", templateId: "fly", name: "Dumbbell Fly", trackingMode: .weightReps, index: 2,
            sets: [WorkoutSetModel(id: "s2", authorId: "author-1", index: 1, isWarmup: false, dateCreated: Date())]
        ))

        await screen.presenter.loadTargets()

        #expect(screen.presenter.targets == ["Bench Press · 65 kg × 8", "Dumbbell Fly"])
    }

    @Test("Test A Failed Prefill Leaves No Targets")
    func testAFailedPrefillLeavesNoTargets() async {
        let screen = makeScreen()
        screen.interactor.startError = URLError(.notConnectedToInternet)

        await screen.presenter.loadTargets()

        #expect(screen.presenter.targets.isEmpty)
        #expect(screen.interactor.trackedEventNames.contains("TodaysWorkoutCard_LoadTargets_Fail"))
    }

    @Test("Test The Block Position Reads Week And Day")
    func testTheBlockPositionReadsWeekAndDay() {
        let screen = makeScreen(cycles: 5)

        #expect(screen.presenter.mesocyclePositionText == "Week 1 of 5 · Day 1")
    }

    private func finished(_ templateId: String, minutes: Double, daysAgo: Double) -> WorkoutSessionModel {
        let start = Date().addingTimeInterval(-daysAgo * 86_400)
        return WorkoutSessionModel(
            authorId: "author-1", name: "Push", workoutTemplateId: templateId,
            dateCreated: start, endedAt: start.addingTimeInterval(minutes * 60), exercises: []
        )
    }

    /// The median of the last five times, so one long session does not set the estimate.
    @Test("Test The Duration Is The Median Of Recent Sessions")
    func testTheDurationIsTheMedianOfRecentSessions() {
        let history = [
            finished("push", minutes: 50, daysAgo: 1),
            finished("push", minutes: 120, daysAgo: 2),
            finished("push", minutes: 55, daysAgo: 3),
            finished("push", minutes: 10, daysAgo: 40),
            finished("pull", minutes: 90, daysAgo: 1)
        ]

        let seconds = TodaysWorkoutCardPresenter.estimatedDuration(of: day, history: history)

        #expect(seconds == 55 * 60)
    }

    /// Never done before: each working set at 2.5 minutes, rest included.
    @Test("Test A New Workout Is Estimated From Its Sets")
    func testANewWorkoutIsEstimatedFromItsSets() {
        var template = day
        template.exercises[0].setTargets = (1...4).map { SetTarget(setNumber: $0, setType: .standard) }

        #expect(TodaysWorkoutCardPresenter.estimatedDuration(of: template, history: []) == 4 * 2.5 * 60)
        let screen = makeScreen()
        #expect(screen.presenter.estimatedDurationText == "~5 min")
        #expect(screen.presenter.startSubtitle == "Week 1 of 4 · Day 1 · ~5 min")
    }

    // MARK: - After the workout

    /// Today's session, its duration, sets (a left/right pair once), volume and records.
    @Test("Test The Finished Workout Shows What It Came To")
    func testTheFinishedWorkoutShowsWhatItCameTo() {
        let screen = makeScreen()
        // Early today, so the session is today's whenever the test runs.
        let start = Calendar.current.startOfDay(for: Date()).addingTimeInterval(60)
        let earlier = Date().addingTimeInterval(-7 * 86_400)
        let bench = { (id: String, kilograms: Double, done: Date) in
            WorkoutExerciseModel(
                id: id, authorId: "author-1", templateId: "bench", name: "Bench Press", trackingMode: .weightReps, index: 1,
                sets: [WorkoutSetModel(id: "\(id)-1", authorId: "author-1", index: 1, reps: 5, weightKg: kilograms, isWarmup: false, completedAt: done, dateCreated: done)]
            )
        }
        let row = WorkoutExerciseModel(
            id: "row", authorId: "author-1", templateId: "row", name: "Row", trackingMode: .weightReps, index: 2,
            sets: [
                WorkoutSetModel(id: "l", authorId: "author-1", index: 1, reps: 10, weightKg: 20, side: .left, isWarmup: false, completedAt: start, dateCreated: start),
                WorkoutSetModel(id: "r", authorId: "author-1", index: 2, reps: 10, weightKg: 20, side: .right, isWarmup: false, completedAt: start, dateCreated: start)
            ]
        )
        let today = WorkoutSessionModel(
            id: "today", authorId: "author-1", name: "Push", workoutTemplateId: "push", mesocycleId: "meso-1",
            dateCreated: start, endedAt: start.addingTimeInterval(52 * 60), exercises: [bench("b2", 100, start), row]
        )
        let lastWeek = WorkoutSessionModel(
            id: "before", authorId: "author-1", name: "Other", dateCreated: earlier,
            endedAt: earlier.addingTimeInterval(3_600), exercises: [bench("b1", 90, earlier)]
        )
        screen.interactor.workoutSessions = [lastWeek, today]

        #expect(screen.presenter.isTodayCompleted)
        let summary = screen.presenter.completedSummary
        #expect(summary?.figures == "52:00 · 2 sets · 900 kg")
        // The count's own wording comes from the catalog's plural rules.
        #expect(summary?.records?.hasSuffix(" · Bench Press 100 kg × 5") == true)

        screen.presenter.onCompletedSessionPressed()

        #expect(screen.router.openedSessionIds == ["today"])
    }

    @Test("Test A Session Not Synced Yet Has No Summary")
    func testASessionNotSyncedYetHasNoSummary() {
        let screen = makeScreen()

        #expect(screen.presenter.completedSummary == nil)
        screen.presenter.onCompletedSessionPressed()
        #expect(screen.router.openedSessionIds.isEmpty)
    }
}
