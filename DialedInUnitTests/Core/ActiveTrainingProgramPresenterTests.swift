//
//  ActiveTrainingProgramPresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 20/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

/// The active training program: which microcycle the user is on, and which of its days they have
/// already done.
///
/// A microcycle is one pass through the program's days. It advances only when *every* day with
/// exercises in it has been completed — not after a fixed number of workouts — and then the ticks
/// clear so the next pass starts empty. Getting that wrong either strands a user on cycle 1 forever
/// or rolls them forward on a partial week, and both look plausible on screen.
///
/// Sessions are matched to days by template id, falling back to the day's name for sessions logged
/// before the program existed. Deload and periodisation are then read off the cycle index.
@MainActor
struct ActiveTrainingProgramPresenterTests {

    private final class Interactor: SpyGlobalInteractor, ActiveTrainingProgramInteractor {
        var activeSession: WorkoutSessionModel?
        var workoutSessions: [WorkoutSessionModel] = []
        private(set) var didDeleteActiveSession = false
        private(set) var deletedProgramIds: [String] = []

        func deleteActiveSession() throws {
            didDeleteActiveSession = true
            activeSession = nil
        }

        var deleteError: Error?

        func deleteTrainingProgram(programId: String) async throws {
            if let deleteError { throw deleteError }
            deletedProgramIds.append(programId)
        }
    }

    private final class Router: ActiveTrainingProgramRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var shown: [String] = []

        func showEditTrainingProgramView(delegate: EditTrainingProgramDelegate) { shown.append("editProgram") }
        func showWorkoutSessionDetailView(delegate: WorkoutSessionDetailDelegate) { shown.append("sessionDetail") }
        func showWorkoutTemplateDetailView(delegate: WorkoutTemplateDetailDelegate) { shown.append("templateDetail") }
        func showWorkoutTrackerView() { shown.append("tracker") }

        private(set) var alertTitles: [String] = []
        func showSimpleAlert(title: String, subtitle: String?) { alertTitles.append(title) }
    }

    private struct Screen {
        let presenter: ActiveTrainingProgramPresenter
        let interactor: Interactor
        let router: Router
    }

    private let start = Date(timeIntervalSince1970: 1_000_000)

    /// A day of the program. Only days with exercises in them count towards a cycle, so `hasExercises`
    /// is the difference between a training day and a placeholder.
    private func day(_ name: String, id: String? = nil, hasExercises: Bool = true) -> WorkoutTemplateModel {
        WorkoutTemplateModel(
            id: id ?? name.lowercased(),
            authorId: "author-1",
            name: name,
            exercises: hasExercises ? [WorkoutTemplateExercise(exercise: .mock, setRestTimers: false)] : []
        )
    }

    private func program(
        days: [WorkoutTemplateModel],
        cycles: Int = 8,
        deload: DeloadType = .none,
        periodisation: Bool = false
    ) -> TrainingProgram {
        TrainingProgram(
            id: "program-1",
            authorId: "author-1",
            name: "Upper/Lower",
            icon: "dumbbell",
            colour: "#FF0000",
            numMicrocycles: cycles,
            deload: deload,
            periodisation: periodisation,
            workoutTemplates: days
        )
    }

    /// A finished session of `day`, attributed to the program by template id unless told otherwise.
    private func session(
        id: String,
        day: WorkoutTemplateModel,
        order: Int,
        programId: String? = "program-1",
        templateId: String? = nil,
        matchByNameOnly: Bool = false
    ) -> WorkoutSessionModel {
        let date = start.addingTimeInterval(Double(order) * 86400)
        return WorkoutSessionModel(
            id: id,
            authorId: "author-1",
            name: day.name,
            workoutTemplateId: matchByNameOnly ? nil : (templateId ?? day.id),
            trainingProgramId: matchByNameOnly ? nil : programId,
            dateCreated: date,
            endedAt: date.addingTimeInterval(3600),
            exercises: []
        )
    }

    private func makeScreen(sessions: [WorkoutSessionModel] = [], active: WorkoutSessionModel? = nil) -> Screen {
        let interactor = Interactor()
        interactor.workoutSessions = sessions
        interactor.activeSession = active
        let router = Router()
        return Screen(
            presenter: ActiveTrainingProgramPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    // MARK: - The day list

    @Test("Test Every Day Of The Program Is Listed")
    func testEveryDayOfTheProgramIsListed() {
        let days = [day("Upper"), day("Lower"), day("Full Body")]
        let screen = makeScreen()

        let items = screen.presenter.currentMicrocycleItems(program: program(days: days))

        #expect(items.map(\.id) == ["upper", "lower", "full body"])
    }

    /// A program with no days of its own is given a default set at init, so the only way to see an
    /// empty list is to ask the presenter about one — which is what the guard is for.
    @Test("Test A Program Without Days Has A Plain Header")
    func testAProgramWithoutDaysHasAPlainHeader() {
        let screen = makeScreen()
        var empty = program(days: [day("Upper")])
        empty.workoutTemplates = []

        let items = screen.presenter.currentMicrocycleItems(program: empty)

        #expect(items.isEmpty)
        #expect(screen.presenter.microcycleHeaderText == "Current Microcycle")
    }

    @Test("Test A Day Nobody Has Trained Is Not Marked Complete")
    func testADayNobodyHasTrainedIsNotMarkedComplete() {
        let days = [day("Upper"), day("Lower")]
        let screen = makeScreen()

        let items = screen.presenter.currentMicrocycleItems(program: program(days: days))

        #expect(items.allSatisfy { !$0.isCompleted })
    }

    @Test("Test A Trained Day Carries Its Session")
    func testATrainedDayCarriesItsSession() throws {
        let days = [day("Upper"), day("Lower")]
        let screen = makeScreen(sessions: [session(id: "s1", day: days[0], order: 1)])

        let items = screen.presenter.currentMicrocycleItems(program: program(days: days))

        #expect(try #require(items.first).completedSessionId == "s1")
        #expect(try #require(items.last).isCompleted == false)
    }

    /// Someone who logged these workouts by hand before building the program should still see them
    /// credited, so a session with no program and no template matches on the day's name.
    @Test("Test A Session Logged Before The Program Matches By Name")
    func testASessionLoggedBeforeTheProgramMatchesByName() throws {
        let days = [day("Upper"), day("Lower")]
        let screen = makeScreen(sessions: [session(id: "s1", day: days[0], order: 1, matchByNameOnly: true)])

        let items = screen.presenter.currentMicrocycleItems(program: program(days: days))

        #expect(try #require(items.first).completedSessionId == "s1")
    }

    @Test("Test A Session From Another Program Is Not Credited")
    func testASessionFromAnotherProgramIsNotCredited() {
        let days = [day("Upper"), day("Lower")]
        let screen = makeScreen(sessions: [session(id: "s1", day: days[0], order: 1, programId: "other-program")])

        let items = screen.presenter.currentMicrocycleItems(program: program(days: days))

        #expect(items.allSatisfy { !$0.isCompleted })
    }

    // MARK: - Advancing the microcycle

    @Test("Test A Fresh Program Starts On The First Microcycle")
    func testAFreshProgramStartsOnTheFirstMicrocycle() {
        let screen = makeScreen()

        _ = screen.presenter.currentMicrocycleItems(program: program(days: [day("Upper"), day("Lower")], cycles: 4))

        #expect(screen.presenter.microcycleHeaderText == "Microcycle 1 of 4")
    }

    /// Part of a cycle is not a cycle.
    @Test("Test Finishing Some Of The Days Does Not Advance The Cycle")
    func testFinishingSomeOfTheDaysDoesNotAdvanceTheCycle() {
        let days = [day("Upper"), day("Lower"), day("Full Body")]
        let screen = makeScreen(sessions: [
            session(id: "s1", day: days[0], order: 1),
            session(id: "s2", day: days[1], order: 2)
        ])

        _ = screen.presenter.currentMicrocycleItems(program: program(days: days, cycles: 4))

        #expect(screen.presenter.microcycleHeaderText == "Microcycle 1 of 4")
    }

    @Test("Test Finishing Every Day Advances The Cycle And Clears The Ticks")
    func testFinishingEveryDayAdvancesTheCycleAndClearsTheTicks() {
        let days = [day("Upper"), day("Lower")]
        let screen = makeScreen(sessions: [
            session(id: "s1", day: days[0], order: 1),
            session(id: "s2", day: days[1], order: 2)
        ])

        let items = screen.presenter.currentMicrocycleItems(program: program(days: days, cycles: 4))

        #expect(screen.presenter.microcycleHeaderText == "Microcycle 2 of 4")
        #expect(items.allSatisfy { !$0.isCompleted })
    }

    /// Repeating a day does not carry the cycle — the user has to train the day they have not done.
    @Test("Test Repeating One Day Does Not Advance The Cycle")
    func testRepeatingOneDayDoesNotAdvanceTheCycle() throws {
        let days = [day("Upper"), day("Lower")]
        let screen = makeScreen(sessions: [
            session(id: "s1", day: days[0], order: 1),
            session(id: "s2", day: days[0], order: 2)
        ])

        let items = screen.presenter.currentMicrocycleItems(program: program(days: days, cycles: 4))

        #expect(screen.presenter.microcycleHeaderText == "Microcycle 1 of 4")
        #expect(try #require(items.first).completedSessionId == "s1")
    }

    /// A rest day or a day still being built has no exercises, so it is not something the user can
    /// complete and the cycle must not wait on it.
    @Test("Test A Day Without Exercises Is Not Required To Advance")
    func testADayWithoutExercisesIsNotRequiredToAdvance() {
        let days = [day("Upper"), day("Rest", hasExercises: false)]
        let screen = makeScreen(sessions: [session(id: "s1", day: days[0], order: 1)])

        _ = screen.presenter.currentMicrocycleItems(program: program(days: days, cycles: 4))

        #expect(screen.presenter.microcycleHeaderText == "Microcycle 2 of 4")
    }

    /// The program repeats rather than ending, so the cycle after the last is the first again.
    @Test("Test The Cycle Wraps Round At The End Of The Program")
    func testTheCycleWrapsRoundAtTheEndOfTheProgram() {
        let days = [day("Upper")]
        let screen = makeScreen(sessions: (1...2).map { session(id: "s\($0)", day: days[0], order: $0) })

        _ = screen.presenter.currentMicrocycleItems(program: program(days: days, cycles: 2))

        #expect(screen.presenter.microcycleHeaderText == "Microcycle 1 of 2")
    }

    // MARK: - Deload

    @Test("Test A Program Without Deload Never Deloads")
    func testAProgramWithoutDeloadNeverDeloads() {
        let screen = makeScreen()
        let plan = program(days: [day("Upper")], cycles: 4, deload: .none)

        #expect((1...4).allSatisfy { !screen.presenter.isCurrentCycleDeload(cycleIndex: $0, program: plan) })
    }

    @Test("Test A Front-Loaded Deload Falls On The First Cycle")
    func testAFrontLoadedDeloadFallsOnTheFirstCycle() {
        let screen = makeScreen()
        let plan = program(days: [day("Upper")], cycles: 4, deload: .start)

        #expect(screen.presenter.isCurrentCycleDeload(cycleIndex: 1, program: plan))
        #expect(!screen.presenter.isCurrentCycleDeload(cycleIndex: 4, program: plan))
    }

    @Test("Test A Trailing Deload Falls On The Last Cycle")
    func testATrailingDeloadFallsOnTheLastCycle() {
        let screen = makeScreen()
        let plan = program(days: [day("Upper")], cycles: 4, deload: .end)

        #expect(screen.presenter.isCurrentCycleDeload(cycleIndex: 4, program: plan))
        #expect(!screen.presenter.isCurrentCycleDeload(cycleIndex: 1, program: plan))
    }

    @Test("Test Reading The Days Sets The Deload Flag")
    func testReadingTheDaysSetsTheDeloadFlag() {
        let screen = makeScreen()

        _ = screen.presenter.currentMicrocycleItems(program: program(days: [day("Upper")], cycles: 4, deload: .start))

        #expect(screen.presenter.isDeloadCycle)
    }

    // MARK: - Periodisation

    @Test("Test A Program Without Periodisation Has No Phase")
    func testAProgramWithoutPeriodisationHasNoPhase() {
        let screen = makeScreen()
        let plan = program(days: [day("Upper")], cycles: 9, periodisation: false)

        #expect(screen.presenter.currentPeriodisationPhase(cycleIndex: 1, program: plan) == nil)
    }

    /// Nine cycles split cleanly into three thirds, one per phase.
    @Test("Test Periodisation Runs Hypertrophy Then Strength Then Power")
    func testPeriodisationRunsHypertrophyThenStrengthThenPower() {
        let screen = makeScreen()
        let plan = program(days: [day("Upper")], cycles: 9, periodisation: true)

        #expect(screen.presenter.currentPeriodisationPhase(cycleIndex: 3, program: plan) == .hypertrophy)
        #expect(screen.presenter.currentPeriodisationPhase(cycleIndex: 6, program: plan) == .strength)
        #expect(screen.presenter.currentPeriodisationPhase(cycleIndex: 9, program: plan) == .power)
    }

    /// A program too short to split three ways still moves through all three phases rather than
    /// collapsing into one, because the third is floored at a single cycle.
    @Test("Test A Short Program Still Reaches Every Phase")
    func testAShortProgramStillReachesEveryPhase() {
        let screen = makeScreen()
        let plan = program(days: [day("Upper")], cycles: 3, periodisation: true)

        #expect(screen.presenter.currentPeriodisationPhase(cycleIndex: 1, program: plan) == .hypertrophy)
        #expect(screen.presenter.currentPeriodisationPhase(cycleIndex: 2, program: plan) == .strength)
        #expect(screen.presenter.currentPeriodisationPhase(cycleIndex: 3, program: plan) == .power)
    }

    @Test("Test Reading The Days Sets The Phase")
    func testReadingTheDaysSetsThePhase() {
        let screen = makeScreen()

        _ = screen.presenter.currentMicrocycleItems(program: program(days: [day("Upper")], cycles: 9, periodisation: true))

        #expect(screen.presenter.periodisationPhase == .hypertrophy)
    }

    // MARK: - Navigation

    @Test("Test Opening A Completed Session Shows It")
    func testOpeningACompletedSessionShowsIt() {
        let days = [day("Upper")]
        let screen = makeScreen(sessions: [session(id: "s1", day: days[0], order: 1)])

        screen.presenter.openCompletedSession(sessionId: "s1")

        #expect(screen.router.shown == ["sessionDetail"])
    }

    /// A session that is no longer there opens nothing rather than an empty screen.
    @Test("Test Opening A Session That Is Gone Shows Nothing")
    func testOpeningASessionThatIsGoneShowsNothing() {
        let screen = makeScreen()

        screen.presenter.openCompletedSession(sessionId: "missing")

        #expect(screen.router.shown.isEmpty)
    }

    /// Nothing opening is a failure, not a non-event. Returning silently after the Start left a
    /// half-funnel: a tap that looked exactly like a screen nobody opened.
    @Test("Test Opening A Session That Is Gone Reports The Failure")
    func testOpeningASessionThatIsGoneReportsTheFailure() {
        let screen = makeScreen()

        screen.presenter.openCompletedSession(sessionId: "missing")

        #expect(screen.interactor.trackedEventNames == [
            "ActiveTrainingProgramView_OpenCompletedSession_Start",
            "ActiveTrainingProgramView_OpenCompletedSession_Fail"
        ])
    }

    @Test("Test Pressing The Program Opens It For Editing")
    func testPressingTheProgramOpensItForEditing() {
        let screen = makeScreen()

        screen.presenter.onProgramPressed(program: program(days: [day("Upper")]))

        #expect(screen.router.shown == ["editProgram"])
    }

    // MARK: - Starting a workout

    @Test("Test Starting A Day Opens Its Template")
    func testStartingADayOpensItsTemplate() {
        let screen = makeScreen()

        screen.presenter.startWorkoutTemplateModelWorkout(day("Upper"), in: "program-1")

        #expect(screen.router.shown == ["templateDetail"])
    }

    /// With a workout already running, starting another asks what to do with it instead of quietly
    /// opening a second one.
    @Test("Test Starting A Day With A Workout Running Asks First")
    func testStartingADayWithAWorkoutRunningAsksFirst() {
        let days = [day("Upper")]
        let live = session(id: "live", day: days[0], order: 1)
        let screen = makeScreen(active: live)

        screen.presenter.startWorkoutTemplateModelWorkout(days[0], in: "program-1")

        #expect(screen.router.shown.isEmpty)
        #expect(!screen.interactor.didDeleteActiveSession)
    }

    // MARK: - Analytics

    @Test("Test Appearing And Leaving Are Both Tracked")
    func testAppearingAndLeavingAreBothTracked() {
        let screen = makeScreen()
        let delegate = ActiveTrainingProgramDelegate(program: program(days: [day("Upper")]))

        screen.presenter.onViewAppear(delegate: delegate)
        screen.presenter.onViewDisappear(delegate: delegate)

        #expect(screen.interactor.trackedScreenEventNames == ["ActiveTrainingProgramView_Appear"])
        #expect(screen.interactor.trackedEventNames == ["ActiveTrainingProgramView_Disappear"])
    }

    /// Deleting was `try?`-ed inside the confirmation button, so a refused delete left the program
    /// in place with no word why.
    @Test("Test A Failed Program Delete Alerts Once")
    func testAFailedProgramDeleteAlertsOnce() async {
        let interactor = Interactor()
        interactor.deleteError = URLError(.notConnectedToInternet)
        let router = Router()
        let presenter = ActiveTrainingProgramPresenter(interactor: interactor, router: router)

        await presenter.deleteTrainingProgram(programId: "program-1")

        #expect(router.alertTitles == ["Unable to Delete Program"])
        #expect(interactor.trackedEventNames == ["ActiveTrainingProgramView_DeleteProgram_Fail"])
    }
}
