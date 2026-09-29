//
//  DashboardCirclePresenterTests.swift
//  DialedInUnitTests
//

import Testing
import Foundation
@testable import DialedIn

// MARK: - Circle strip

/// The row of faces over the feed: who trained today, who can still be nudged.
///
/// "Today" is the device's local day, so these sessions are dated relative to now — anchored an
/// hour after midnight so a run at 23:59 does not push a session's end into tomorrow.
@MainActor
struct DashboardCirclePresenterTests {

    private typealias Interactor = DashboardFeedPresenterTests.Interactor
    private typealias Router = DashboardFeedPresenterTests.Router

    private struct Screen {
        let presenter: DashboardPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen(following: [UserModel] = []) -> Screen {
        let interactor = Interactor()
        interactor.followingUsers = following
        let router = Router()
        return Screen(presenter: DashboardPresenter(interactor: interactor, router: router), interactor: interactor, router: router)
    }

    private var earlyToday: Date { Calendar.current.startOfDay(for: .now).addingTimeInterval(3600) }
    private var yesterday: Date { Calendar.current.startOfDay(for: .now).addingTimeInterval(-12 * 3600) }

    private func names(_ screen: Screen) -> [String] {
        screen.presenter.circleMembers.map(\.user.userId)
    }

    @Test("Test The Strip Is Hidden When Following Nobody")
    func testTheStripIsHiddenWhenFollowingNobody() {
        let screen = makeScreen()
        screen.interactor.workoutSessions = [DashboardFixture.session(id: "mine", on: earlyToday)]
        #expect(screen.presenter.circleMembers.isEmpty)
    }

    @Test("Test The Strip Holds Everyone Followed Plus The User")
    func testTheStripHoldsEveryoneFollowedPlusTheUser() {
        let screen = makeScreen(following: [DashboardFixture.user("amy", firstName: "Amy")])
        #expect(Set(names(screen)) == ["me", "amy"])
    }

    /// Only a finished, non-rest session ending today counts. A rest day, a session still under
    /// way and yesterday's workout all leave the face grey.
    @Test("Test Trained Today Needs A Finished Non Rest Session Ending Today")
    func testTrainedTodayNeedsAFinishedNonRestSessionEndingToday() {
        let screen = makeScreen(following: [
            DashboardFixture.user("amy", firstName: "Amy"),
            DashboardFixture.user("bob", firstName: "Bob"),
            DashboardFixture.user("cal", firstName: "Cal"),
            DashboardFixture.user("dee", firstName: "Dee")
        ])
        screen.interactor.workoutSessions = [DashboardFixture.session(id: "mine", on: earlyToday)]
        screen.interactor.followingWorkoutSessions = [
            DashboardFixture.session(id: "a", author: "amy", on: earlyToday),
            DashboardFixture.session(id: "b", author: "bob", on: earlyToday, isRestDay: true),
            DashboardFixture.session(id: "c", author: "cal", on: earlyToday, finished: false),
            DashboardFixture.session(id: "d", author: "dee", on: yesterday)
        ]

        let trained = screen.presenter.circleMembers.filter { $0.trainedToday }.map(\.user.userId)
        #expect(Set(trained) == ["me", "amy"])
    }

    /// Trained first, then alphabetical by name within each group, the user included.
    @Test("Test The Strip Orders Trained First Then By Name")
    func testTheStripOrdersTrainedFirstThenByName() {
        let screen = makeScreen(following: [
            DashboardFixture.user("zed", firstName: "Zed"),
            DashboardFixture.user("cal", firstName: "Cal"),
            DashboardFixture.user("amy", firstName: "amy"),
            DashboardFixture.user("bob", firstName: "Bob")
        ])
        screen.interactor.followingWorkoutSessions = [
            DashboardFixture.session(id: "z", author: "zed", on: earlyToday),
            DashboardFixture.session(id: "c", author: "cal", on: earlyToday)
        ]

        #expect(names(screen) == ["cal", "zed", "amy", "bob", "me"])
    }

    @Test("Test A Blocked Account Is Not In The Strip")
    func testABlockedAccountIsNotInTheStrip() {
        let screen = makeScreen(following: [DashboardFixture.user("amy"), DashboardFixture.user("bob")])
        screen.interactor.currentUser = UserModel(userId: "me", submittedFirstName: "me", blockedUserIds: ["bob"])
        #expect(Set(names(screen)) == ["me", "amy"])
    }

    @Test("Test Tapping A Face Opens That Persons Profile")
    func testTappingAFaceOpensThatPersonsProfile() throws {
        let screen = makeScreen(following: [DashboardFixture.user("amy")])
        let amy = try #require(screen.presenter.circleMembers.first { $0.user.userId == "amy" })

        screen.presenter.onCircleMemberPressed(amy)

        #expect(screen.router.shown == ["socialProfile:amy"])
    }

    // MARK: Nudges

    /// Only someone else who has not trained can be nudged.
    @Test("Test Only An Untrained Friend Can Be Nudged")
    func testOnlyAnUntrainedFriendCanBeNudged() {
        let screen = makeScreen(following: [DashboardFixture.user("amy"), DashboardFixture.user("bob")])
        screen.interactor.followingWorkoutSessions = [DashboardFixture.session(id: "a", author: "amy", on: earlyToday)]

        let nudgeable = screen.presenter.circleMembers.filter { $0.canNudge }.map(\.user.userId)
        #expect(nudgeable == ["bob"])
    }

    @Test("Test A Nudge Is Written Once And The Button Goes")
    func testANudgeIsWrittenOnceAndTheButtonGoes() async throws {
        let screen = makeScreen(following: [DashboardFixture.user("bob")])
        let bob = try #require(screen.presenter.circleMembers.first { $0.user.userId == "bob" })

        screen.presenter.onNudgePressed(bob)
        // A second tap on the stale cell before the view redraws must not send another.
        screen.presenter.onNudgePressed(bob)

        #expect(await TestManagers.eventually { screen.interactor.nudgeWrites == ["bob"] })
        #expect(screen.presenter.circleMembers.first { $0.user.userId == "bob" }?.canNudge == false)
        #expect(screen.interactor.trackedEventNames.contains("DashboardView_Nudge_Press"))
    }

    /// The day's log is read on appearance, so a nudge sent earlier today is not offered again.
    @Test("Test Someone Already Nudged Today Cannot Be Nudged Again")
    func testSomeoneAlreadyNudgedTodayCannotBeNudgedAgain() {
        let screen = makeScreen(following: [DashboardFixture.user("bob")])
        screen.interactor.nudgedUserIdsToday = ["bob"]

        screen.presenter.onViewAppear(delegate: DashboardDelegate())

        #expect(screen.presenter.circleMembers.first { $0.user.userId == "bob" }?.canNudge == false)
    }

    @Test("Test A Failed Nudge Gives The Button Back And Says So")
    func testAFailedNudgeGivesTheButtonBackAndSaysSo() async throws {
        let screen = makeScreen(following: [DashboardFixture.user("bob", firstName: "Bob")])
        screen.interactor.nudgeError = DashboardTestError.failed
        let bob = try #require(screen.presenter.circleMembers.first { $0.user.userId == "bob" })

        screen.presenter.onNudgePressed(bob)

        #expect(await TestManagers.eventually { screen.router.alertTitles == ["Unable to nudge Bob"] })
        #expect(screen.presenter.circleMembers.first { $0.user.userId == "bob" }?.canNudge == true)
        #expect(screen.interactor.nudgeWrites.isEmpty)
    }
}

// MARK: - Nudge log

/// The device-side record of who was nudged today, which is what makes it one per person per day.
@MainActor
struct NudgeHistoryManagerTests {

    private func freshDefaults() throws -> UserDefaults {
        let name = "NudgeHistoryManagerTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("Test Nudges Are Remembered For The Day And Forgotten The Next")
    func testNudgesAreRememberedForTheDayAndForgottenTheNext() throws {
        let defaults = try freshDefaults()
        let today = DashboardFixture.date(day: 10, hour: 9)
        let laterToday = DashboardFixture.date(day: 10, hour: 22)
        let tomorrow = DashboardFixture.date(day: 11, hour: 8)

        NudgeHistoryManager.addNudge(userId: "bob", on: today, userDefaults: defaults)
        NudgeHistoryManager.addNudge(userId: "amy", on: laterToday, userDefaults: defaults)
        #expect(NudgeHistoryManager.nudgedUserIds(on: laterToday, userDefaults: defaults) == ["bob", "amy"])
        #expect(NudgeHistoryManager.nudgedUserIds(on: tomorrow, userDefaults: defaults).isEmpty)

        // The first nudge of a new day replaces the old day's list rather than adding to it.
        NudgeHistoryManager.addNudge(userId: "cal", on: tomorrow, userDefaults: defaults)
        #expect(NudgeHistoryManager.nudgedUserIds(on: tomorrow, userDefaults: defaults) == ["cal"])
    }
}
