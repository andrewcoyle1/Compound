//
//  DashboardPresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

enum DashboardTestError: Error { case failed }

/// Fixtures for the Dashboard and the social screens behind it.
///
/// Dates are fixed and deliberately not today, so anything reaching for the current date instead of
/// the one it was handed fails rather than passing by coincidence.
@MainActor
enum DashboardFixture {
    static let calendar = Calendar.current

    static func date(month: Int = 3, day: Int, hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour)) ?? .distantPast
    }

    static func user(_ id: String, firstName: String? = nil) -> UserModel {
        UserModel(userId: id, submittedFirstName: firstName ?? id)
    }

    /// A finished, non-rest session unless told otherwise — the only shape the feed is meant to show.
    static func session(
        id: String,
        author: String = "me",
        name: String = "Push Day",
        on date: Date,
        finished: Bool = true,
        isRestDay: Bool = false,
        likedBy: [String] = [],
        exercises: [WorkoutExerciseModel] = []
    ) -> WorkoutSessionModel {
        WorkoutSessionModel(
            id: id,
            authorId: author,
            name: name,
            dateCreated: date,
            endedAt: finished ? date.addingTimeInterval(3600) : nil,
            exercises: exercises,
            isRestDay: isRestDay,
            likedByUserIds: likedBy
        )
    }
}

// MARK: - Dashboard

/// The Dashboard: the carousel of cards and, below it, the workout feed.
///
/// The feed is the risk. It mixes the signed-in user's own sessions with those of everyone they
/// follow, and every row is attributed to a person — so the two things that must never go wrong are
/// what gets shown (nothing unfinished, nothing dated in the future) and whose name is on it.
///
/// `dismissScreen()` and `showLoadingModal()` are `GlobalRouter` extension methods and dispatch
/// statically, so a double can never see them; the alert methods are requirements and this double
/// really does intercept them.
@MainActor
struct DashboardFeedPresenterTests {

    /// Internal rather than private so `DashboardCirclePresenterTests` can share the doubles.
    final class Interactor: SpyGlobalInteractor, DashboardInteractor {
        var userId: String? = "me"
        func acceptInvite(code: String) async throws -> (inviter: UserModel, acceptance: InviteAcceptance) {
            throw InviteError.notFound
        }
        var inviteFails = false
        func myInvite() async throws -> InviteModel {
            if inviteFails { throw InviteError.unavailable }
            return InviteModel(code: "PUSH2345", inviterId: "me")
        }
        var userImageUrl: String?
        var currentUser: UserModel? = DashboardFixture.user("me")
        var draftMeal: MealLogModel?
        var workoutSessions: [WorkoutSessionModel] = []
        var activityNotifications: [ActivityNotificationModel] = []
        var incomingFollowRequests: [FollowRequestModel] = []
        var followingWorkoutSessions: [WorkoutSessionModel] = []
        var followingUsers: [UserModel] = []
        var activeTrainingProgram: TrainingProgram?
        var totals: DailyMacroTarget?
        var target: DailyMacroTarget?
        var notificationsError: Error?
        var suggestedUsers: [UserModel] = []
        private(set) var suggestedFetchCount = 0
        private(set) var deletedDraftCount = 0
        private(set) var fetchedNotificationsCount = 0
        private(set) var followedUserIds: [String] = []
        private(set) var unfollowedUserIds: [String] = []
        private(set) var totalsDayKeys: [String] = []
        var nudgedUserIdsToday: Set<String> = []
        var nudgeError: Error?
        private(set) var nudgeWrites: [String] = []

        func deleteDraftMeal() throws {
            deletedDraftCount += 1
            draftMeal = nil
        }

        func followUser(userId: String) async throws { followedUserIds.append(userId) }

        func unfollowUser(userId: String) async throws { unfollowedUserIds.append(userId) }

        func nudgeUser(userId: String) async throws {
            if let nudgeError { throw nudgeError }
            nudgeWrites.append(userId)
            nudgedUserIdsToday.insert(userId)
        }
        var sentFollowRequestIds: Set<String> = []
        func sendFollowRequest(to user: UserModel) async throws { sentFollowRequestIds.insert(user.userId) }
        func cancelFollowRequest(userId: String) async throws { sentFollowRequestIds.remove(userId) }

        func fetchActivityNotifications() async throws {
            fetchedNotificationsCount += 1
            if let notificationsError { throw notificationsError }
        }

        func fetchSuggestedUsers() async throws -> [UserModel] {
            suggestedFetchCount += 1
            return suggestedUsers
        }

        func getDailyTotals(dayKey: String) throws -> DailyMacroTarget {
            totalsDayKeys.append(dayKey)
            guard let totals else { throw DashboardTestError.failed }
            return totals
        }

        func getDailyTarget(for date: Date, userId: String) async throws -> DailyMacroTarget? {
            target
        }

        var fetchableSessions: [WorkoutSessionModel] = []

        func fetchWorkoutSession(id: String, authorId: String) async throws -> WorkoutSessionModel {
            guard let session = fetchableSessions.first(where: { $0.id == id && $0.authorId == authorId }) else {
                throw DashboardTestError.failed
            }
            return session
        }

        // MARK: - Challenges
        var challenges: [ChallengeModel] = []
        var challengeProgressById: [String: [String: Int]] = [:]
        private(set) var challengeRefreshCount = 0
        func challengeProgress(challengeId: String) -> [String: Int] { challengeProgressById[challengeId] ?? [:] }
        func refreshChallenges() async throws { challengeRefreshCount += 1 }
        // MARK: - FeedLoading
        var hasLoadedFollowingSessions = true
    }

    /// `showDevSettingsView()` is declared unguarded: the protocol wraps it in `#if DEV || MOCK` but
    /// the test target builds without those flags.
    final class Router: DashboardRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var shown: [String] = []
        private(set) var alertTitles: [String] = []
        private(set) var addMealDelegates: [AddMealDelegate] = []

        func showDevSettingsView() { shown.append("devSettings") }
        func showProfileViewZoom(transitionId: String?, namespace: Namespace.ID) { shown.append("profile") }
        func showNotificationsView() { shown.append("notifications") }
        func showNutritionView() { shown.append("nutrition") }
        func showSocialProfileView(delegate: SocialProfileDelegate) { shown.append("socialProfile:\(delegate.user.userId)") }
        func showWorkoutSessionDetailView(delegate: WorkoutSessionDetailDelegate) { shown.append("session:\(delegate.initialSession.id)") }
        func showWorkoutSessionThread(delegate: WorkoutSessionDetailDelegate) { shown.append("thread:\(delegate.initialSession.id)") }
        func showEditUsernameView() { shown.append("editUsername") }
        func showWeeklyGoalView() { shown.append("weeklyGoal") }
        // MARK: - Challenges
        func showChallengeDetailView(delegate: ChallengeDetailDelegate) { shown.append("challenge:\(delegate.challenge.id)") }
        func showCreateChallengeView() { shown.append("createChallenge") }
        // MARK: - WeeklyReview
        func showWeeklyReviewView() { shown.append("weeklyReview") }
        func showShareSheet(items: [Any]) { shown.append("share: \(items.first as? String ?? "")") }

        func showAddMealView(delegate: AddMealDelegate) {
            shown.append("addMeal")
            addMealDelegates.append(delegate)
        }

        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) {
            alertTitles.append(title)
        }

        func showSimpleAlert(title: String, subtitle: String?) {
            alertTitles.append(title)
        }
    }

    private struct Screen {
        let presenter: DashboardPresenter
        let interactor: Interactor
        let router: Router
        let delegate = DashboardDelegate()
    }

    private func makeScreen() -> Screen {
        let interactor = Interactor()
        let router = Router()
        return Screen(
            presenter: DashboardPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    // MARK: Opening a session from a push

    /// A push tap relayed by the tab bar opens the session it names, and a comment or mention
    /// opens its thread on top.
    @Test("Test A Session Push Opens The Session And A Comment Push Its Thread")
    func testASessionPushOpensTheSessionAndACommentPushItsThread() async {
        let screen = makeScreen()
        screen.interactor.fetchableSessions = [DashboardFixture.session(id: "s1", author: "friend", on: DashboardFixture.date(day: 2))]

        screen.presenter.onOpenWorkoutSessionNotificationReceived(Notification(
            name: Constants.openWorkoutSession, object: nil,
            userInfo: ["session_id": "s1", "session_author_id": "friend", "type": "like"]
        ))
        await TestManagers.eventually { screen.router.shown == ["session:s1"] }
        screen.presenter.onOpenWorkoutSessionNotificationReceived(Notification(
            name: Constants.openWorkoutSession, object: nil,
            userInfo: ["session_id": "s1", "session_author_id": "friend", "type": "mention"]
        ))
        await TestManagers.eventually { screen.router.shown.count == 2 }

        #expect(screen.router.shown == ["session:s1", "thread:s1"])
    }

    /// Best effort: a session that cannot be fetched leaves the user on the Dashboard, with no alert.
    @Test("Test A Session Push That Cannot Be Fetched Does Nothing")
    func testASessionPushThatCannotBeFetchedDoesNothing() async {
        let screen = makeScreen()

        screen.presenter.onOpenWorkoutSessionNotificationReceived(Notification(
            name: Constants.openWorkoutSession, object: nil,
            userInfo: ["session_id": "gone", "session_author_id": "friend", "type": "comment"]
        ))
        await TestManagers.eventually(timeout: .milliseconds(200)) { !screen.router.shown.isEmpty }

        #expect(screen.router.shown.isEmpty)
        #expect(screen.router.alertTitles.isEmpty)
    }

    // MARK: Feed contents

    /// The newest workout is the one people came to see, so the feed reads downwards in time
    /// regardless of whose session it is or which list it arrived in.
    @Test("Test The Feed Is Newest First Across Both Sources")
    func testTheFeedIsNewestFirstAcrossBothSources() {
        let screen = makeScreen()
        screen.interactor.followingUsers = [DashboardFixture.user("friend")]
        screen.interactor.workoutSessions = [
            DashboardFixture.session(id: "mine-old", on: DashboardFixture.date(day: 1)),
            DashboardFixture.session(id: "mine-new", on: DashboardFixture.date(day: 5))
        ]
        screen.interactor.followingWorkoutSessions = [
            DashboardFixture.session(id: "theirs", author: "friend", on: DashboardFixture.date(day: 3))
        ]

        #expect(screen.presenter.feedSessions.map(\.id) == ["mine-new", "theirs", "mine-old"])
    }

    /// Blocking unfollows, but the following sync can still hold a blocked author's sessions until
    /// it next emits, and an account blocked before blocking unfollowed may still be followed.
    @Test("Test A Blocked Authors Session Is Not In The Feed")
    func testABlockedAuthorsSessionIsNotInTheFeed() {
        let screen = makeScreen()
        screen.interactor.currentUser = UserModel(userId: "me", submittedFirstName: "me", blockedUserIds: ["blocked"])
        screen.interactor.followingUsers = [DashboardFixture.user("friend"), DashboardFixture.user("blocked")]
        screen.interactor.followingWorkoutSessions = [
            DashboardFixture.session(id: "theirs", author: "friend", on: DashboardFixture.date(day: 3)),
            DashboardFixture.session(id: "hidden", author: "blocked", on: DashboardFixture.date(day: 4))
        ]

        #expect(screen.presenter.feedSessions.map(\.id) == ["theirs"])
    }

    /// A workout still being logged is not an achievement to show anyone — including its own author,
    /// who is still in the gym doing it.
    @Test("Test An Unfinished Session Of Your Own Is Not In The Feed")
    func testAnUnfinishedSessionOfYourOwnIsNotInTheFeed() {
        let screen = makeScreen()
        screen.interactor.workoutSessions = [
            DashboardFixture.session(id: "in-progress", on: DashboardFixture.date(day: 4), finished: false),
            DashboardFixture.session(id: "done", on: DashboardFixture.date(day: 4))
        ]

        #expect(screen.presenter.feedSessions.map(\.id) == ["done"])
    }

    /// A rest day is a gap in the plan, not a workout. Programs pre-create them, so letting one
    /// through would post "Rest Day" to the feed on the user's behalf.
    @Test("Test A Rest Day Of Your Own Is Not In The Feed")
    func testARestDayOfYourOwnIsNotInTheFeed() {
        let screen = makeScreen()
        screen.interactor.workoutSessions = [
            DashboardFixture.session(id: "rest", on: DashboardFixture.date(day: 4), isRestDay: true),
            DashboardFixture.session(id: "done", on: DashboardFixture.date(day: 4))
        ]

        #expect(screen.presenter.feedSessions.map(\.id) == ["done"])
    }

    /// A followed athlete's workout is theirs to publish when they finish it. While it is still
    /// being logged it is nobody else's business, and the feed used to show it the moment it
    /// started because only the reader's own sessions were filtered.
    @Test("Test A Followed Users Unfinished Session Is Not In The Feed")
    func testAFollowedUsersUnfinishedSessionIsNotInTheFeed() {
        let screen = makeScreen()
        screen.interactor.followingUsers = [DashboardFixture.user("friend")]
        screen.interactor.followingWorkoutSessions = [
            DashboardFixture.session(id: "theirs-live", author: "friend", on: DashboardFixture.date(day: 4), finished: false),
            DashboardFixture.session(id: "theirs-done", author: "friend", on: DashboardFixture.date(day: 4))
        ]

        #expect(screen.presenter.feedSessions.map(\.id) == ["theirs-done"])
    }

    /// A program pre-creates its rest days, dated ahead of time and already marked finished. Those
    /// are a plan, not something that happened — showing one posts "Rest Day" to the feed on a
    /// followed user's behalf, for a day that has not arrived.
    @Test("Test A Followed Users Future Rest Day Is Not In The Feed")
    func testAFollowedUsersFutureRestDayIsNotInTheFeed() {
        let screen = makeScreen()
        screen.interactor.followingUsers = [DashboardFixture.user("friend")]
        screen.interactor.followingWorkoutSessions = [
            DashboardFixture.session(
                id: "theirs-rest",
                author: "friend",
                name: "Rest Day",
                on: Date().addingTimeInterval(86_400),
                isRestDay: true
            ),
            DashboardFixture.session(id: "theirs-done", author: "friend", on: DashboardFixture.date(day: 4))
        ]

        #expect(screen.presenter.feedSessions.map(\.id) == ["theirs-done"])
    }

    /// A session whose author cannot be named — someone unfollowed, or a row that arrived before
    /// their profile did — has no row to draw. It is dropped here so the screen knows the feed is
    /// empty, rather than showing a header above nothing.
    @Test("Test A Session With No Resolvable Author Is Dropped")
    func testASessionWithNoResolvableAuthorIsDropped() {
        let screen = makeScreen()
        screen.interactor.followingUsers = []
        screen.interactor.followingWorkoutSessions = [
            DashboardFixture.session(id: "orphan", author: "stranger", on: DashboardFixture.date(day: 4))
        ]

        #expect(screen.presenter.feedSessions.isEmpty)
    }

    @Test("Test An Empty Feed Has No Rows")
    func testAnEmptyFeedHasNoRows() {
        let screen = makeScreen()

        #expect(screen.presenter.feedSessions.isEmpty)
    }

    // MARK: Suggested people

    /// Suggestions belong to the empty state only: a reader with a feed never pays for the fetch.
    @Test("Test Suggested People Load Only For An Empty Feed")
    func testSuggestedPeopleLoadOnlyForAnEmptyFeed() async {
        let screen = makeScreen()
        screen.interactor.suggestedUsers = [DashboardFixture.user("a")]
        screen.interactor.workoutSessions = [DashboardFixture.session(id: "mine", on: DashboardFixture.date(day: 1))]

        await screen.presenter.loadSuggestedUsers()
        #expect(screen.interactor.suggestedFetchCount == 0)
        #expect(screen.presenter.visibleSuggestedUsers.isEmpty)

        screen.interactor.workoutSessions = []
        await screen.presenter.loadSuggestedUsers()
        #expect(screen.interactor.suggestedFetchCount == 1)
        #expect(screen.presenter.visibleSuggestedUsers.map(\.userId) == ["a"])
    }

    /// Following someone from the list drops them out of it, and the row opens their profile.
    @Test("Test Following A Suggested Person Removes Them And A Row Opens Their Profile")
    func testFollowingASuggestedPersonRemovesThemAndARowOpensTheirProfile() async {
        let screen = makeScreen()
        screen.interactor.suggestedUsers = [DashboardFixture.user("a"), DashboardFixture.user("b")]
        await screen.presenter.loadSuggestedUsers()

        screen.presenter.onFollowButtonPressed(user: DashboardFixture.user("a"))
        await TestManagers.eventually { !screen.interactor.followedUserIds.isEmpty }
        screen.interactor.currentUser = UserModel(userId: "me", followingIds: ["a"])
        screen.presenter.onSuggestedUserPressed(user: DashboardFixture.user("b"))

        #expect(screen.interactor.followedUserIds == ["a"])
        #expect(screen.presenter.visibleSuggestedUsers.map(\.userId) == ["b"])
        #expect(screen.presenter.followState(for: DashboardFixture.user("a")) == .following)
        #expect(screen.router.shown == ["socialProfile:b"])
    }

    // MARK: Authorship

    /// Every row carries a name and a face. Taking the author from the followed-users list means a
    /// session can only ever be shown under the person who actually logged it.
    @Test("Test A Followed Users Session Is Attributed To Them")
    func testAFollowedUsersSessionIsAttributedToThem() {
        let screen = makeScreen()
        let friend = DashboardFixture.user("friend")
        let other = DashboardFixture.user("other")
        screen.interactor.followingUsers = [other, friend]
        let session = DashboardFixture.session(id: "theirs", author: "friend", on: DashboardFixture.date(day: 2))

        #expect(screen.presenter.author(for: session)?.userId == friend.userId)
    }

    /// The signed-in user is not in their own following list, so without this their own sessions
    /// would have no author at all.
    @Test("Test Your Own Session Is Attributed To You")
    func testYourOwnSessionIsAttributedToYou() {
        let screen = makeScreen()
        let signedIn = DashboardFixture.user("me", firstName: "Andrew")
        screen.interactor.currentUser = signedIn
        let session = DashboardFixture.session(id: "mine", author: "me", on: DashboardFixture.date(day: 2))

        #expect(screen.presenter.author(for: session)?.userId == signedIn.userId)
    }

    /// A session from someone who is neither the signed-in user nor followed has nobody to name it
    /// after — the row must not fall back to whoever happens to be first.
    @Test("Test A Session From A Stranger Has No Author")
    func testASessionFromAStrangerHasNoAuthor() {
        let screen = makeScreen()
        screen.interactor.followingUsers = [DashboardFixture.user("friend")]
        let session = DashboardFixture.session(id: "theirs", author: "stranger", on: DashboardFixture.date(day: 2))

        #expect(screen.presenter.author(for: session) == nil)
    }

    // MARK: Cards

    @Test("Test There Is No Todays Workout Without A Program")
    func testThereIsNoTodaysWorkoutWithoutAProgram() {
        let screen = makeScreen()

        #expect(screen.presenter.hasActiveProgram == false)
        #expect(screen.presenter.todaysWorkoutTemplate == nil)
        #expect(screen.presenter.isTodayCompleted == false)
    }

    /// With a program running, the card offers the next day plan in the rotation, and nothing is
    /// marked done until a session says so.
    @Test("Test An Active Program Offers Todays Workout")
    func testAnActiveProgramOffersTodaysWorkout() {
        let screen = makeScreen()
        let template = WorkoutTemplateModel(
            id: "push",
            authorId: "me",
            name: "Push",
            exercises: [WorkoutTemplateExercise(exercise: .mock, setRestTimers: false)]
        )
        screen.interactor.activeTrainingProgram = TrainingProgram(
            id: "program-1",
            authorId: "me",
            name: "Base",
            icon: "dumbbell",
            colour: "#FF0000",
            workoutTemplates: [template]
        )

        #expect(screen.presenter.hasActiveProgram)
        #expect(screen.presenter.todaysWorkoutTemplate?.id == "push")
        #expect(screen.presenter.isTodayCompleted == false)
    }

    // MARK: Nutrition card

    /// The card is filled on appear rather than on a refresh, so opening the tab after logging
    /// breakfast shows breakfast.
    @Test("Test Appearing Loads Todays Nutrition Totals And Target")
    func testAppearingLoadsTodaysNutritionTotalsAndTarget() async {
        let screen = makeScreen()
        screen.interactor.totals = DailyMacroTarget(calories: 900, proteinGrams: 50, carbGrams: 80, fatGrams: 30)
        screen.interactor.target = DailyMacroTarget.mock

        screen.presenter.onViewAppear(delegate: screen.delegate)
        await TestManagers.eventually { screen.presenter.nutritionTarget != nil }

        #expect(screen.presenter.nutritionTotals?.calories == 900)
        #expect(screen.presenter.nutritionTarget?.calories == DailyMacroTarget.mock.calories)
        // Today's key, not a stored one: the card is always about the day the user is looking at.
        #expect(screen.interactor.totalsDayKeys == [Date().dayKey])
    }

    /// A day with nothing logged throws rather than returning zeroes, and the card falls back to its
    /// own defaults — it must not take the screen down with it.
    @Test("Test A Failed Totals Read Leaves The Card Empty")
    func testAFailedTotalsReadLeavesTheCardEmpty() {
        let screen = makeScreen()
        screen.interactor.totals = nil

        screen.presenter.onViewAppear(delegate: screen.delegate)

        #expect(screen.presenter.nutritionTotals == nil)
    }

    // MARK: Logging a meal

    /// The common case: a tap opens a fresh meal, authored by the signed-in user and dated today.
    @Test("Test Logging A Meal Opens A New Meal For Today")
    func testLoggingAMealOpensANewMealForToday() {
        let screen = makeScreen()

        screen.presenter.onLogMealPressed()

        #expect(screen.router.shown == ["addMeal"])
        #expect(screen.router.addMealDelegates.first?.mealLog.authorId == "me")
        #expect(screen.router.addMealDelegates.first?.mealLog.dayKey == Date().dayKey)
        #expect(screen.router.alertTitles.isEmpty)
    }

    /// A half-finished meal is unsaved work. Rather than silently starting a second one, the user is
    /// asked what to do with the one they already have.
    @Test("Test A Draft Meal Asks Before Starting Another")
    func testADraftMealAsksBeforeStartingAnother() {
        let screen = makeScreen()
        screen.interactor.draftMeal = MealLogModel(
            authorId: "me",
            dayKey: Date().dayKey,
            date: Date(),
            items: []
        )

        screen.presenter.onLogMealPressed()

        #expect(screen.router.alertTitles == ["Unable to add new meal"])
        #expect(screen.router.shown.isEmpty)
        #expect(screen.interactor.deletedDraftCount == 0)
    }

    /// Signed out there is nobody to author the meal, so nothing happens rather than a meal logged
    /// against an empty user id.
    @Test("Test Logging A Meal Does Nothing Without A Signed In User")
    func testLoggingAMealDoesNothingWithoutASignedInUser() {
        let screen = makeScreen()
        screen.interactor.currentUser = nil

        screen.presenter.onLogMealPressed()

        #expect(screen.router.shown.isEmpty)
        #expect(screen.router.alertTitles.isEmpty)
    }

    // MARK: Notifications and navigation

    @Test("Test Activity Notifications Come Straight From The Interactor")
    func testActivityNotificationsComeStraightFromTheInteractor() {
        let screen = makeScreen()
        let notifications = ActivityNotificationModel.mocks
        screen.interactor.activityNotifications = notifications

        #expect(screen.presenter.activityNotifications.map(\.id) == notifications.map(\.id))
    }

    /// The badge is drawn from this, so a failed fetch has to leave the screen standing rather than
    /// surfacing an error over a dashboard.
    @Test("Test A Failed Notification Fetch Is Swallowed")
    func testAFailedNotificationFetchIsSwallowed() async {
        let screen = makeScreen()
        screen.interactor.notificationsError = DashboardTestError.failed

        await screen.presenter.loadNotifications()

        #expect(screen.interactor.fetchedNotificationsCount == 1)
    }

    /// The bell counts unread activity and pending follow requests together, and a request that
    /// arrives on the live listener raises it without any fetch.
    @Test("Test The Bell Badge Adds Pending Follow Requests")
    func testTheBellBadgeAddsPendingFollowRequests() {
        let screen = makeScreen()
        screen.interactor.activityNotifications = [false, true].enumerated().map { index, isRead in
            ActivityNotificationModel(
                id: "n\(index)", type: .like, actorId: "a", actorName: "A", actorImageUrl: nil,
                sessionId: "s", sessionAuthorId: "me", commentText: nil, dateCreated: DashboardFixture.date(day: 1), isRead: isRead
            )
        }
        #expect(screen.presenter.bellBadgeCount == 1)

        screen.interactor.incomingFollowRequests = ["fan", "friend"].map {
            FollowRequestModel(requesterId: $0, requesterName: $0, requesterImageUrl: nil, dateCreated: DashboardFixture.date(day: 1), status: .pending)
        }

        #expect(screen.presenter.bellBadgeCount == 3)
    }

    @Test("Test The Bell Opens The Notifications Screen")
    func testTheBellOpensTheNotificationsScreen() {
        let screen = makeScreen()

        screen.presenter.onPushNotificationsPressed()

        #expect(screen.router.shown == ["notifications"])
    }

    /// People search lives on the Search tab and only the tab bar can select a tab, so the empty
    /// feed's call to action asks for it through `NotificationCenter` rather than navigating itself.
    @Test("Test Find People Asks The Tab Bar For The Search Tab")
    func testFindPeopleAsksTheTabBarForTheSearchTab() async {
        let screen = makeScreen()
        var receivedTab: String?
        let observer = NotificationCenter.default.addObserver(
            forName: Constants.selectTab,
            object: nil,
            queue: .main
        ) { notification in
            receivedTab = notification.userInfo?["tab"] as? String
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        screen.presenter.onFindPeoplePressed()
        await TestManagers.eventually { receivedTab != nil }

        #expect(receivedTab == DeepLink.Tab.search.rawValue)
        #expect(screen.interactor.trackedEventNames.contains("DashboardView_FindPeople_Press"))
        #expect(screen.router.shown.isEmpty)
    }

    @Test("Test Appearing And Disappearing Are Tracked")
    func testAppearingAndDisappearingAreTracked() {
        let screen = makeScreen()

        screen.presenter.onViewAppear(delegate: screen.delegate)
        screen.presenter.onViewDisappear(delegate: screen.delegate)

        #expect(screen.interactor.trackedScreenEventNames == ["DashboardView_Appear"])
        #expect(screen.interactor.trackedEventNames == ["DashboardView_Disappear"])
    }
}
