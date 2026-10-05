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
        var startError: Error?

        func skipScheduledWorkout(_ slot: MesocycleSchedule.Slot) async throws { }

        func deleteActiveSession() throws { activeSession = nil }

        func startWorkout(for template: WorkoutTemplateModel, in mesocycleId: String?) async throws {
            if let startError { throw startError }
            startedTemplateIds.append(template.id)
            activeSession = WorkoutSessionModel(
                id: "started",
                authorId: "author-1",
                name: template.name,
                workoutTemplateId: template.id,
                mesocycleId: mesocycleId,
                dateCreated: Date(),
                exercises: [WorkoutExerciseModel(
                    id: "e1",
                    authorId: "author-1",
                    templateId: "ex",
                    name: "Bench Press",
                    trackingMode: .weightReps,
                    index: 1,
                    sets: [WorkoutSetModel(id: "s1", authorId: "author-1", index: 1, reps: 8, weightKg: 100, isWarmup: false, dateCreated: Date())]
                )]
            )
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
}
