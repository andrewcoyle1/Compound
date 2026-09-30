//
//  ActiveMesocyclePresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 20/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

/// The active training mesocycle: which microcycle the user is on, and which of its days they have
/// already done.
///
/// A microcycle is one pass through the mesocycle's days. It advances only when *every* day with
/// exercises in it has been completed — not after a fixed number of workouts — and then the ticks
/// clear so the next pass starts empty. Getting that wrong either strands a user on cycle 1 forever
/// or rolls them forward on a partial week, and both look plausible on screen.
///
/// Sessions are matched to days by template id, falling back to the day's name for sessions logged
/// before the mesocycle existed. Deload and periodisation are then read off the cycle index.
@MainActor
struct ActiveMesocyclePresenterTests {

    private final class Interactor: SpyGlobalInteractor, ActiveMesocycleInteractor {
        var activeSession: WorkoutSessionModel?
        var workoutSessions: [WorkoutSessionModel] = []
        var activeMesocycleRun: MesocycleSchedule.Run?
        var currentMacrocycle: Macrocycle?
        private(set) var skippedSlotIds: [String] = []
        private(set) var didDeleteActiveSession = false

        func skipScheduledWorkout(_ slot: MesocycleSchedule.Slot) async throws {
            skippedSlotIds.append(slot.id)
        }
        private(set) var deletedMesocycleIds: [String] = []

        func deleteActiveSession() throws {
            didDeleteActiveSession = true
            activeSession = nil
        }

        var deleteError: Error?

        func deleteMesocycle(mesocycleId: String) async throws {
            if let deleteError { throw deleteError }
            deletedMesocycleIds.append(mesocycleId)
        }
    }

    private final class Router: ActiveMesocycleRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var shown: [String] = []

        func showEditMesocycleView(delegate: EditMesocycleDelegate) { shown.append("editProgram") }
        func showWorkoutSessionDetailView(delegate: WorkoutSessionDetailDelegate) { shown.append("sessionDetail") }
        func showWorkoutTemplateDetailView(delegate: WorkoutTemplateDetailDelegate) { shown.append("templateDetail") }
        func showWorkoutTrackerView() { shown.append("tracker") }

        private(set) var alertTitles: [String] = []
        func showSimpleAlert(title: String, subtitle: String?) { alertTitles.append(title) }
    }

    private struct Screen {
        let presenter: ActiveMesocyclePresenter
        let interactor: Interactor
        let router: Router
    }

    private let start = Date(timeIntervalSince1970: 1_000_000)

    /// A day of the mesocycle. Only days with exercises in them count towards a cycle, so `hasExercises`
    /// is the difference between a training day and a placeholder.
    private func day(_ name: String, id: String? = nil, hasExercises: Bool = true) -> WorkoutTemplateModel {
        WorkoutTemplateModel(
            id: id ?? name.lowercased(),
            authorId: "author-1",
            name: name,
            exercises: hasExercises ? [WorkoutTemplateExercise(exercise: .mock, setRestTimers: false)] : []
        )
    }

    private func mesocycle(
        days: [WorkoutTemplateModel],
        cycles: Int = 8,
        deload: DeloadType = .none,
        periodisation: Bool = false
    ) -> Mesocycle {
        Mesocycle(
            id: "program-1",
            authorId: "author-1",
            name: "Upper/Lower",
            icon: "dumbbell",
            colour: "#FF0000",
            numMicrocycles: cycles,
            deload: deload,
            periodisation: periodisation,
            workoutTemplates: days,
            dateCreated: start
        )
    }

    /// A finished session of `day`, attributed to the mesocycle by template id unless told otherwise.
    private func session(
        id: String,
        day: WorkoutTemplateModel,
        order: Int,
        mesocycleId: String? = "program-1",
        templateId: String? = nil,
        matchByNameOnly: Bool = false
    ) -> WorkoutSessionModel {
        let date = start.addingTimeInterval(Double(order) * 86400)
        return WorkoutSessionModel(
            id: id,
            authorId: "author-1",
            name: day.name,
            workoutTemplateId: matchByNameOnly ? nil : (templateId ?? day.id),
            mesocycleId: matchByNameOnly ? nil : mesocycleId,
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
            presenter: ActiveMesocyclePresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    // MARK: - The day list

    @Test("Test Every Day Of The Program Is Listed")
    func testEveryDayOfTheMesocycleIsListed() {
        let days = [day("Upper"), day("Lower"), day("Full Body")]
        let screen = makeScreen()

        let items = screen.presenter.microcycleItems(mesocycle: mesocycle(days: days))

        #expect(items.map(\.workoutTemplate.id) == ["upper", "lower", "full body"])
    }

    /// A mesocycle with no days of its own is given a default set at init, so the only way to see an
    /// empty list is to ask the presenter about one — which is what the guard is for.
    @Test("Test A Program Without Days Has A Plain Header")
    func testAMesocycleWithoutDaysHasAPlainHeader() {
        let screen = makeScreen()
        var empty = mesocycle(days: [day("Upper")])
        empty.workoutTemplates = []

        let items = screen.presenter.microcycleItems(mesocycle: empty)

        #expect(items.isEmpty)
        #expect(screen.presenter.microcycleHeaderText == "Current Microcycle")
    }

    @Test("Test A Day Nobody Has Trained Is Not Marked Complete")
    func testADayNobodyHasTrainedIsNotMarkedComplete() {
        let days = [day("Upper"), day("Lower")]
        let screen = makeScreen()

        let items = screen.presenter.microcycleItems(mesocycle: mesocycle(days: days))

        #expect(items.allSatisfy { !$0.isCompleted })
    }

    @Test("Test A Trained Day Carries Its Session")
    func testATrainedDayCarriesItsSession() throws {
        let days = [day("Upper"), day("Lower")]
        let screen = makeScreen(sessions: [session(id: "s1", day: days[0], order: 1)])

        let items = screen.presenter.microcycleItems(mesocycle: mesocycle(days: days))

        #expect(try #require(items.first).completedSessionId == "s1")
        #expect(try #require(items.last).isCompleted == false)
    }

    /// Someone who logged these workouts by hand before building the mesocycle should still see them
    /// credited, so a session with no mesocycle and no template matches on the day's name.
    @Test("Test A Session Logged Before The Program Matches By Name")
    func testASessionLoggedBeforeTheMesocycleMatchesByName() throws {
        let days = [day("Upper"), day("Lower")]
        let screen = makeScreen(sessions: [session(id: "s1", day: days[0], order: 1, matchByNameOnly: true)])

        let items = screen.presenter.microcycleItems(mesocycle: mesocycle(days: days))

        #expect(try #require(items.first).completedSessionId == "s1")
    }

    @Test("Test A Session From Another Program Is Not Credited")
    func testASessionFromAnotherMesocycleIsNotCredited() {
        let days = [day("Upper"), day("Lower")]
        let screen = makeScreen(sessions: [session(id: "s1", day: days[0], order: 1, mesocycleId: "other-program")])

        let items = screen.presenter.microcycleItems(mesocycle: mesocycle(days: days))

        #expect(items.allSatisfy { !$0.isCompleted })
    }

    // MARK: - Advancing the microcycle

    @Test("Test A Fresh Program Starts On The First Microcycle")
    func testAFreshMesocycleStartsOnTheFirstMicrocycle() {
        let screen = makeScreen()

        _ = screen.presenter.microcycleItems(mesocycle: mesocycle(days: [day("Upper"), day("Lower")], cycles: 4))

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

        _ = screen.presenter.microcycleItems(mesocycle: mesocycle(days: days, cycles: 4))

        #expect(screen.presenter.microcycleHeaderText == "Microcycle 1 of 4")
    }

    @Test("Test Finishing Every Day Advances The Cycle And Clears The Ticks")
    func testFinishingEveryDayAdvancesTheCycleAndClearsTheTicks() {
        let days = [day("Upper"), day("Lower")]
        let screen = makeScreen(sessions: [
            session(id: "s1", day: days[0], order: 1),
            session(id: "s2", day: days[1], order: 2)
        ])

        let items = screen.presenter.microcycleItems(mesocycle: mesocycle(days: days, cycles: 4))

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

        let items = screen.presenter.microcycleItems(mesocycle: mesocycle(days: days, cycles: 4))

        #expect(screen.presenter.microcycleHeaderText == "Microcycle 1 of 4")
        #expect(try #require(items.first).completedSessionId == "s1")
    }

    /// A rest day or a day still being built has no exercises, so it is not something the user can
    /// complete and the cycle must not wait on it.
    @Test("Test A Day Without Exercises Is Not Required To Advance")
    func testADayWithoutExercisesIsNotRequiredToAdvance() {
        let days = [day("Upper"), day("Rest", hasExercises: false)]
        let screen = makeScreen(sessions: [session(id: "s1", day: days[0], order: 1)])

        _ = screen.presenter.microcycleItems(mesocycle: mesocycle(days: days, cycles: 4))

        #expect(screen.presenter.microcycleHeaderText == "Microcycle 2 of 4")
    }

    /// A finished block stays on its last microcycle, every day ticked, until the plan moves on.
    /// It used to wrap silently back to the first.
    @Test("Test A Finished Block Stays On Its Last Microcycle")
    func testAFinishedBlockStaysOnItsLastMicrocycle() {
        let days = [day("Upper")]
        let screen = makeScreen(sessions: (1...2).map { session(id: "s\($0)", day: days[0], order: $0) })
        let followed = mesocycle(days: days, cycles: 2)
        screen.interactor.activeMesocycleRun = MesocycleSchedule.Run(mesocycle: followed, startedAt: start)

        let items = screen.presenter.microcycleItems(mesocycle: followed)

        #expect(screen.presenter.microcycleHeaderText == "Microcycle 2 of 2")
        #expect(items.allSatisfy { $0.isCompleted })
    }

    /// Sessions from before the block started belong to an earlier run of it.
    @Test("Test Sessions Before The Block Started Are Not Credited")
    func testSessionsBeforeTheBlockStartedAreNotCredited() {
        let days = [day("Upper"), day("Lower")]
        let screen = makeScreen(sessions: [session(id: "s1", day: days[0], order: 1)])
        let followed = mesocycle(days: days, cycles: 4)
        screen.interactor.activeMesocycleRun = MesocycleSchedule.Run(mesocycle: followed, startedAt: start.addingTimeInterval(10 * 86400))

        let items = screen.presenter.microcycleItems(mesocycle: followed)

        #expect(items.allSatisfy { !$0.isCompleted })
    }

    // MARK: - Browsing microcycles

    @Test("Test Picking A Microcycle Shows Past And Future Ones")
    func testPickingAMicrocycleShowsPastAndFutureOnes() throws {
        let days = [day("Upper"), day("Lower")]
        let screen = makeScreen(sessions: [
            session(id: "s1", day: days[0], order: 1),
            session(id: "s2", day: days[1], order: 2)
        ])
        let followed = mesocycle(days: days, cycles: 3)

        _ = screen.presenter.microcycleItems(mesocycle: followed)
        #expect(screen.presenter.cycleCount == 3)
        #expect(screen.presenter.displayedCycleIndex == 1)
        #expect(screen.presenter.cycleMenuTitle(1) == "Microcycle 2 (Current)")
        #expect(screen.presenter.cycleMenuTitle(0) == "Microcycle 1")

        screen.presenter.onCycleSelected(0)
        let past = screen.presenter.microcycleItems(mesocycle: followed)
        #expect(screen.presenter.microcycleHeaderText == "Microcycle 1 of 3")
        #expect(past.allSatisfy { $0.timing == .past && $0.isCompleted })

        screen.presenter.onCycleSelected(2)
        let future = screen.presenter.microcycleItems(mesocycle: followed)
        #expect(screen.presenter.microcycleHeaderText == "Microcycle 3 of 3")
        #expect(future.allSatisfy { $0.timing == .future && !$0.canSkip })

        screen.presenter.onCycleSelected(1)
        _ = screen.presenter.microcycleItems(mesocycle: followed)
        #expect(screen.presenter.viewedCycleIndex == nil)
    }

    @Test("Test Picking A Microcycle Out Of Range Is Ignored")
    func testPickingAMicrocycleOutOfRangeIsIgnored() {
        let screen = makeScreen()
        _ = screen.presenter.microcycleItems(mesocycle: mesocycle(days: [day("Upper")], cycles: 2))

        screen.presenter.onCycleSelected(5)

        #expect(screen.presenter.viewedCycleIndex == nil)
    }

    /// A day in a later microcycle is a preview: it opens the template without a start button.
    @Test("Test A Future Day Opens As A Preview")
    func testAFutureDayOpensAsAPreview() throws {
        let screen = makeScreen()
        let followed = mesocycle(days: [day("Upper")], cycles: 2)
        _ = screen.presenter.microcycleItems(mesocycle: followed)
        screen.presenter.onCycleSelected(1)

        let item = try #require(screen.presenter.microcycleItems(mesocycle: followed).first)
        screen.presenter.onItemPressed(item)

        #expect(screen.router.shown == ["templateDetail"])
        #expect(screen.interactor.activeSession == nil)
    }

    @Test("Test A Skipped Day Shows As Skipped And Cannot Be Skipped Again")
    func testASkippedDayShowsAsSkipped() throws {
        let days = [day("Upper"), day("Lower")]
        let screen = makeScreen()
        let followed = mesocycle(days: days, cycles: 2)
        screen.interactor.activeMesocycleRun = MesocycleSchedule.Run(
            mesocycle: followed,
            startedAt: start,
            skips: [CycleSkip(mesocycleIndex: 0, cycleIndex: 0, position: 0, templateId: "upper", date: start)]
        )

        let items = screen.presenter.microcycleItems(mesocycle: followed)

        #expect(try #require(items.first).isSkipped)
        #expect(try #require(items.first).canSkip == false)
        #expect(try #require(items.last).isToday)
    }

    @Test("Test Skipping A Day Asks The Plan To Skip Its Slot")
    func testSkippingADayAsksThePlanToSkipItsSlot() async throws {
        let screen = makeScreen()
        let items = screen.presenter.microcycleItems(mesocycle: mesocycle(days: [day("Upper"), day("Lower")], cycles: 2))
        let first = try #require(items.first)

        screen.presenter.onSkipPressed(first)

        #expect(await TestManagers.eventually { screen.interactor.skippedSlotIds == [first.id] })
    }

    // MARK: - Deload

    @Test("Test A Program Without Deload Never Deloads")
    func testAMesocycleWithoutDeloadNeverDeloads() {
        let screen = makeScreen()
        let plan = mesocycle(days: [day("Upper")], cycles: 4, deload: .none)

        #expect((1...4).allSatisfy { !screen.presenter.isCurrentCycleDeload(cycleIndex: $0, mesocycle: plan) })
    }

    @Test("Test A Front-Loaded Deload Falls On The First Cycle")
    func testAFrontLoadedDeloadFallsOnTheFirstCycle() {
        let screen = makeScreen()
        let plan = mesocycle(days: [day("Upper")], cycles: 4, deload: .start)

        #expect(screen.presenter.isCurrentCycleDeload(cycleIndex: 1, mesocycle: plan))
        #expect(!screen.presenter.isCurrentCycleDeload(cycleIndex: 4, mesocycle: plan))
    }

    @Test("Test A Trailing Deload Falls On The Last Cycle")
    func testATrailingDeloadFallsOnTheLastCycle() {
        let screen = makeScreen()
        let plan = mesocycle(days: [day("Upper")], cycles: 4, deload: .end)

        #expect(screen.presenter.isCurrentCycleDeload(cycleIndex: 4, mesocycle: plan))
        #expect(!screen.presenter.isCurrentCycleDeload(cycleIndex: 1, mesocycle: plan))
    }

    @Test("Test Reading The Days Sets The Deload Flag")
    func testReadingTheDaysSetsTheDeloadFlag() {
        let screen = makeScreen()

        _ = screen.presenter.microcycleItems(mesocycle: mesocycle(days: [day("Upper")], cycles: 4, deload: .start))

        #expect(screen.presenter.isDeloadCycle)
    }

    // MARK: - Periodisation

    @Test("Test A Program Without Periodisation Has No Phase")
    func testAMesocycleWithoutPeriodisationHasNoPhase() {
        let screen = makeScreen()
        let plan = mesocycle(days: [day("Upper")], cycles: 9, periodisation: false)

        #expect(screen.presenter.currentPeriodisationPhase(cycleIndex: 1, mesocycle: plan) == nil)
    }

    /// Nine cycles split cleanly into three thirds, one per phase.
    @Test("Test Periodisation Runs Hypertrophy Then Strength Then Power")
    func testPeriodisationRunsHypertrophyThenStrengthThenPower() {
        let screen = makeScreen()
        let plan = mesocycle(days: [day("Upper")], cycles: 9, periodisation: true)

        #expect(screen.presenter.currentPeriodisationPhase(cycleIndex: 3, mesocycle: plan) == .hypertrophy)
        #expect(screen.presenter.currentPeriodisationPhase(cycleIndex: 6, mesocycle: plan) == .strength)
        #expect(screen.presenter.currentPeriodisationPhase(cycleIndex: 9, mesocycle: plan) == .power)
    }

    /// A mesocycle too short to split three ways still moves through all three phases rather than
    /// collapsing into one, because the third is floored at a single cycle.
    @Test("Test A Short Program Still Reaches Every Phase")
    func testAShortMesocycleStillReachesEveryPhase() {
        let screen = makeScreen()
        let plan = mesocycle(days: [day("Upper")], cycles: 3, periodisation: true)

        #expect(screen.presenter.currentPeriodisationPhase(cycleIndex: 1, mesocycle: plan) == .hypertrophy)
        #expect(screen.presenter.currentPeriodisationPhase(cycleIndex: 2, mesocycle: plan) == .strength)
        #expect(screen.presenter.currentPeriodisationPhase(cycleIndex: 3, mesocycle: plan) == .power)
    }

    @Test("Test Reading The Days Sets The Phase")
    func testReadingTheDaysSetsThePhase() {
        let screen = makeScreen()

        _ = screen.presenter.microcycleItems(mesocycle: mesocycle(days: [day("Upper")], cycles: 9, periodisation: true))

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
    func testPressingTheMesocycleOpensItForEditing() {
        let screen = makeScreen()

        screen.presenter.onMesocyclePressed(mesocycle: mesocycle(days: [day("Upper")]))

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
        let delegate = ActiveMesocycleDelegate(mesocycle: mesocycle(days: [day("Upper")]))

        screen.presenter.onViewAppear(delegate: delegate)
        screen.presenter.onViewDisappear(delegate: delegate)

        #expect(screen.interactor.trackedScreenEventNames == ["ActiveTrainingProgramView_Appear"])
        #expect(screen.interactor.trackedEventNames == ["ActiveTrainingProgramView_Disappear"])
    }

    /// Deleting was `try?`-ed inside the confirmation button, so a refused delete left the mesocycle
    /// in place with no word why.
    @Test("Test A Failed Program Delete Alerts Once")
    func testAFailedMesocycleDeleteAlertsOnce() async {
        let interactor = Interactor()
        interactor.deleteError = URLError(.notConnectedToInternet)
        let router = Router()
        let presenter = ActiveMesocyclePresenter(interactor: interactor, router: router)

        await presenter.deleteMesocycle(mesocycleId: "program-1")

        #expect(router.alertTitles == ["Unable to Delete Program"])
        #expect(interactor.trackedEventNames == ["ActiveTrainingProgramView_DeleteProgram_Fail"])
    }
}
