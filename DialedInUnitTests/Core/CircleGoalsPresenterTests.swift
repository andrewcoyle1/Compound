//
//  CircleGoalsPresenterTests.swift
//  DialedInUnitTests
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

// MARK: - Weekly goal sheet

@MainActor
struct WeeklyGoalPresenterTests {

    final class Interactor: SpyGlobalInteractor, WeeklyGoalInteractor {
        var currentUser: UserModel?
        var saveError: Error?
        private(set) var savedGoals: [Int] = []

        init(currentUser: UserModel?) {
            self.currentUser = currentUser
        }

        func updateWeeklySessionGoal(_ goal: Int) async throws {
            if let saveError { throw saveError }
            savedGoals.append(goal)
        }
    }

    final class Router: WeeklyGoalRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var alertTitles: [String] = []

        func showDevSettingsView() { }
        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) {
            alertTitles.append(title)
        }
        func showSimpleAlert(title: String, subtitle: String?) {
            alertTitles.append(title)
        }
    }

    @Test("Test The Stepper Starts At The Saved Goal Or Three")
    func testTheStepperStartsAtTheSavedGoalOrThree() {
        let unset = WeeklyGoalPresenter(interactor: Interactor(currentUser: UserModel(userId: "me")), router: Router())
        let saved = WeeklyGoalPresenter(interactor: Interactor(currentUser: UserModel(userId: "me", weeklySessionGoal: 5)), router: Router())
        #expect(unset.goal == 3)
        #expect(saved.goal == 5)
    }

    @Test("Test Saving Writes The Goal Clamped To One Through Seven")
    func testSavingWritesTheGoalClampedToOneThroughSeven() async {
        let interactor = Interactor(currentUser: UserModel(userId: "me"))
        let presenter = WeeklyGoalPresenter(interactor: interactor, router: Router())

        presenter.goal = 9
        presenter.onSavePressed()

        #expect(await TestManagers.eventually { interactor.savedGoals == [7] })
        #expect(interactor.trackedEventNames.contains("WeeklyGoalView_Save_Pressed"))
    }

    @Test("Test A Failed Save Says So")
    func testAFailedSaveSaysSo() async {
        let interactor = Interactor(currentUser: UserModel(userId: "me"))
        interactor.saveError = DashboardTestError.failed
        let router = Router()
        let presenter = WeeklyGoalPresenter(interactor: interactor, router: router)

        presenter.onSavePressed()

        #expect(await TestManagers.eventually { router.alertTitles == ["Unable to save your goal"] })
        #expect(await TestManagers.eventually { !presenter.isSaving })
    }
}

// MARK: - Dashboard wiring

@MainActor
struct DashboardCircleGoalsPresenterTests {

    private typealias Interactor = DashboardFeedPresenterTests.Interactor
    private typealias Router = DashboardFeedPresenterTests.Router

    private var earlyToday: Date { Calendar.current.startOfDay(for: .now).addingTimeInterval(3600) }

    private struct Screen {
        let presenter: DashboardPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen(following: [UserModel]) -> Screen {
        let interactor = Interactor()
        interactor.followingUsers = following
        let router = Router()
        return Screen(presenter: DashboardPresenter(interactor: interactor, router: router), interactor: interactor, router: router)
    }

    @Test("Test Each Face Carries Its Weeks Sessions And Goal")
    func testEachFaceCarriesItsWeeksSessionsAndGoal() throws {
        let screen = makeScreen(following: [UserModel(userId: "amy", submittedFirstName: "Amy", weeklySessionGoal: 5)])
        screen.interactor.workoutSessions = [DashboardFixture.session(id: "m", on: earlyToday)]
        screen.interactor.followingWorkoutSessions = [
            DashboardFixture.session(id: "a1", author: "amy", on: earlyToday),
            DashboardFixture.session(id: "a2", author: "amy", on: earlyToday.addingTimeInterval(60))
        ]

        let amy = try #require(screen.presenter.circleMembers.first { $0.user.userId == "amy" })
        let mine = try #require(screen.presenter.circleMembers.first { $0.user.userId == "me" })
        #expect(amy.sessionsThisWeek == 2 && amy.weeklyGoal == 5 && !amy.isCurrentUser)
        #expect(mine.sessionsThisWeek == 1 && mine.weeklyGoal == 3 && mine.isCurrentUser)
    }

    @Test("Test The Leaderboard Ranks The Strip And A Row Opens The Profile")
    func testTheLeaderboardRanksTheStripAndARowOpensTheProfile() throws {
        let screen = makeScreen(following: [DashboardFixture.user("amy")])
        screen.interactor.followingWorkoutSessions = [DashboardFixture.session(id: "a1", author: "amy", on: earlyToday)]

        #expect(screen.presenter.circleStandings.map(\.id) == ["amy", "me"])

        screen.presenter.onLeaderboardRowPressed(try #require(screen.presenter.circleStandings.first))
        #expect(screen.router.shown == ["socialProfile:amy"])
    }

    @Test("Test Following Nobody Leaves No Leaderboard Or Recap")
    func testFollowingNobodyLeavesNoLeaderboardOrRecap() {
        let screen = makeScreen(following: [])
        #expect(screen.presenter.circleStandings.isEmpty)
        #expect(screen.presenter.weeklySummary == nil)
    }

    @Test("Test The Strip Offers A Goal Until One Is Set")
    func testTheStripOffersAGoalUntilOneIsSet() {
        let screen = makeScreen(following: [DashboardFixture.user("amy")])
        #expect(screen.presenter.showsWeeklyGoalPrompt)

        screen.presenter.onSetWeeklyGoalPressed()
        #expect(screen.router.shown == ["weeklyGoal"])

        screen.interactor.currentUser = UserModel(userId: "me", weeklySessionGoal: 4)
        #expect(!screen.presenter.showsWeeklyGoalPrompt)
    }
}

// MARK: - Own profile

@MainActor
struct SocialProfileWeeklyGoalTests {

    private typealias Interactor = SocialProfilePresenterTests.Interactor
    private typealias Router = SocialProfilePresenterTests.Router

    @Test("Test Only The Owner Sees And Edits Their Goal")
    func testOnlyTheOwnerSeesAndEditsTheirGoal() {
        let interactor = Interactor()
        let router = Router()
        let presenter = SocialProfilePresenter(interactor: interactor, router: router)

        presenter.onViewAppear(delegate: SocialProfileDelegate(user: DashboardFixture.user("me")))
        #expect(presenter.weeklyGoalText == "Set a weekly goal")
        interactor.currentUser = UserModel(userId: "me", weeklySessionGoal: 4)
        #expect(presenter.weeklyGoalText == "Goal: 4 sessions a week")
        presenter.onWeeklyGoalPressed()
        #expect(router.weeklyGoalShownCount == 1)

        presenter.onViewAppear(delegate: SocialProfileDelegate(user: DashboardFixture.user("friend")))
        #expect(presenter.weeklyGoalText == nil)
        presenter.onWeeklyGoalPressed()
        #expect(router.weeklyGoalShownCount == 1)
    }
}
