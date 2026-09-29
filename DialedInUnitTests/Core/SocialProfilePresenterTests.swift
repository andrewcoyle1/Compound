//
//  SocialProfilePresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

// MARK: - Social profile

/// Someone else's profile, reached from a feed row.
///
/// The counts here describe that person, not the reader, and "people you both follow" is an
/// intersection — getting it wrong tells the reader they follow someone they do not.
@MainActor
struct SocialProfilePresenterTests {

    final class Interactor: SpyGlobalInteractor, SocialProfileInteractor {
        var currentUser: UserModel? = DashboardFixture.user("me")
        var followingUsers: [UserModel] = []
        var followers: [UserModel] = []
        var fetchError: Error?
        var followError: Error?
        var workoutSessions: [WorkoutSessionModel] = []
        var activeTrainingProgram: TrainingProgram?
        var remoteSessions: [WorkoutSessionModel] = []
        private(set) var fetchedFollowerIds: [String] = []
        private(set) var fetchedSessionAuthorIds: [String] = []

        func fetchWorkoutSessions(authorId: String, limit: Int) async throws -> [WorkoutSessionModel] {
            fetchedSessionAuthorIds.append(authorId)
            return remoteSessions
        }

        func fetchFollowers(userId: String) async throws -> [UserModel] {
            fetchedFollowerIds.append(userId)
            if let fetchError { throw fetchError }
            return followers
        }

        func followUser(userId: String) async throws {
            if let followError { throw followError }
            currentUser = UserModel(userId: "me", followingIds: (currentUser?.followingIds ?? []) + [userId])
        }

        func unfollowUser(userId: String) async throws {
            if let followError { throw followError }
            currentUser = UserModel(userId: "me", followingIds: (currentUser?.followingIds ?? []).filter { $0 != userId })
        }

        var sentFollowRequestIds: Set<String> = []
        func sendFollowRequest(to user: UserModel) async throws {
            if let followError { throw followError }
            sentFollowRequestIds.insert(user.userId)
        }
        func cancelFollowRequest(userId: String) async throws { sentFollowRequestIds.remove(userId) }

        var usersById: [String: UserModel] = [:]
        private(set) var fetchedUserIds: [[String]] = []
        func fetchUsers(userIds: [String]) async throws -> [UserModel] {
            fetchedUserIds.append(userIds)
            return userIds.compactMap { usersById[$0] }
        }

        private(set) var blockedIds: [String] = []
        private(set) var unblockedIds: [String] = []
        private(set) var reports: [String] = []

        /// Mirrors `UserManager.blockUser`: the block and the unfollow land together.
        func blockUser(userId: String) async throws {
            blockedIds.append(userId)
            currentUser = UserModel(
                userId: "me",
                blockedUserIds: (currentUser?.blockedUserIds ?? []) + [userId],
                followingIds: (currentUser?.followingIds ?? []).filter { $0 != userId }
            )
        }

        func unblockUser(userId: String) async throws {
            unblockedIds.append(userId)
            currentUser = UserModel(
                userId: "me",
                blockedUserIds: (currentUser?.blockedUserIds ?? []).filter { $0 != userId },
                followingIds: currentUser?.followingIds
            )
        }

        func report(
            contentType: ReportContentType,
            contentId: String,
            authorUserId: String?,
            reason: ReportReason,
            notes: String?
        ) async throws {
            reports.append("\(contentType.rawValue)|\(contentId)|\(authorUserId ?? "")|\(reason.rawValue)")
        }
    }

    final class Router: SocialProfileRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var followersDelegates: [FollowersListDelegate] = []
        private(set) var alertTitles: [String] = []

        func showFollowersList(delegate: FollowersListDelegate) {
            followersDelegates.append(delegate)
        }

        private(set) var weeklyGoalShownCount = 0
        func showWeeklyGoalView() { weeklyGoalShownCount += 1 }

        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) {
            alertTitles.append(title)
        }
        func showSimpleAlert(title: String, subtitle: String?) {
            alertTitles.append(title)
        }
    }

    private struct Screen {
        let presenter: SocialProfilePresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen() -> Screen {
        let interactor = Interactor()
        let router = Router()
        return Screen(
            presenter: SocialProfilePresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    private func profile(_ id: String, following: [String]?) -> SocialProfileDelegate {
        SocialProfileDelegate(user: UserModel(userId: id, followingIds: following))
    }

    /// Another user's sessions load on appear; the section shows a spinner until they land rather
    /// than flashing "No workouts yet".
    @Test("Test Sessions Show Loading Until The Fetch Lands")
    func testSessionsShowLoadingUntilTheFetchLands() async {
        let screen = makeScreen()

        screen.presenter.onViewAppear(delegate: profile("friend", following: []))
        #expect(screen.presenter.isLoadingSessions)

        #expect(await TestManagers.eventually(timeout: .seconds(5)) { !screen.presenter.isLoadingSessions })
        #expect(screen.interactor.fetchedSessionAuthorIds == ["friend"])
    }

    /// The followers shown are the profile's own, fetched for that user id — never the reader's.
    @Test("Test Appearing Loads The Profiles Followers")
    func testAppearingLoadsTheProfilesFollowers() async {
        let screen = makeScreen()
        screen.interactor.followers = [DashboardFixture.user("a"), DashboardFixture.user("b")]

        screen.presenter.onViewAppear(delegate: profile("friend", following: []))
        await TestManagers.eventually { !screen.presenter.followers.isEmpty }

        #expect(screen.interactor.fetchedFollowerIds == ["friend"])
        #expect(screen.presenter.followersCount == 2)
        #expect(screen.interactor.trackedScreenEventNames == ["SocialProfileView_Appear"])
    }

    /// A profile nobody follows, or one whose followers cannot be fetched, reads as zero rather than
    /// carrying over whatever was on screen before.
    @Test("Test A Failed Follower Fetch Leaves The Count At Zero")
    func testAFailedFollowerFetchLeavesTheCountAtZero() async {
        let screen = makeScreen()
        screen.interactor.fetchError = DashboardTestError.failed

        screen.presenter.onViewAppear(delegate: profile("friend", following: ["a"]))
        await TestManagers.eventually { !screen.interactor.fetchedFollowerIds.isEmpty }

        #expect(screen.presenter.followersCount == 0)
    }

    /// Following count is the profile's own list, and a profile that follows nobody has none rather
    /// than an unknown.
    @Test("Test The Following Count Is The Profiles Own")
    func testTheFollowingCountIsTheProfilesOwn() {
        let screen = makeScreen()

        screen.presenter.onViewAppear(delegate: profile("friend", following: ["a", "b", "c"]))
        #expect(screen.presenter.followingCount == 3)

        screen.presenter.onViewAppear(delegate: profile("friend", following: nil))
        #expect(screen.presenter.followingCount == 0)
    }

    /// "People you both follow" is the overlap of the reader's following list and the profile's, so
    /// someone only one of them follows must not appear.
    @Test("Test Mutual Followers Are The Overlap Of Both Lists")
    func testMutualFollowersAreTheOverlapOfBothLists() {
        let screen = makeScreen()
        screen.interactor.followingUsers = [
            DashboardFixture.user("shared"),
            DashboardFixture.user("mine-only")
        ]

        screen.presenter.onViewAppear(delegate: profile("friend", following: ["shared", "theirs-only"]))

        #expect(screen.presenter.mutualFollowers.map(\.userId) == ["shared"])
    }

    /// Before the profile is known there is nothing to intersect with, so the strip of shared faces
    /// stays empty rather than showing the reader their own following list.
    @Test("Test There Are No Mutual Followers Before The Profile Loads")
    func testThereAreNoMutualFollowersBeforeTheProfileLoads() {
        let screen = makeScreen()
        screen.interactor.followingUsers = [DashboardFixture.user("shared")]

        #expect(screen.presenter.mutualFollowers.isEmpty)
    }

    /// Two doors into the same list screen, each carrying its own people and its own title — the
    /// mutual list is not the followers list.
    @Test("Test The Two Follower Lists Open With Their Own People And Titles")
    func testTheTwoFollowerListsOpenWithTheirOwnPeopleAndTitles() async {
        let screen = makeScreen()
        screen.interactor.followers = [DashboardFixture.user("a")]
        screen.interactor.followingUsers = [DashboardFixture.user("shared")]
        screen.presenter.onViewAppear(delegate: profile("friend", following: ["shared"]))
        await TestManagers.eventually { !screen.presenter.followers.isEmpty }

        screen.presenter.onFollowersPressed()
        screen.presenter.onMutualFollowersPressed()

        #expect(screen.router.followersDelegates.map(\.title) == ["Followers", "People You Both Follow"])
        #expect(screen.router.followersDelegates.first?.followers.map(\.userId) == ["a"])
        #expect(screen.router.followersDelegates.last?.followers.map(\.userId) == ["shared"])
    }

    /// Only the reader's own followers list offers Remove.
    @Test("Test Only The Readers Own Followers Can Be Removed")
    func testOnlyTheReadersOwnFollowersCanBeRemoved() async {
        let screen = makeScreen()
        screen.interactor.followers = [DashboardFixture.user("a")]

        screen.presenter.onViewAppear(delegate: profile("friend", following: []))
        await TestManagers.eventually { !screen.presenter.followers.isEmpty }
        screen.presenter.onFollowersPressed()

        screen.presenter.onViewAppear(delegate: profile("me", following: []))
        screen.presenter.onFollowersPressed()

        #expect(screen.router.followersDelegates.map(\.canRemoveFollowers) == [false, true])
    }

    /// The button reads the reader's own following list, so following flips it and unfollowing
    /// flips it back — and the reader's own profile never shows one.
    @Test("Test Following A Profile Flips The Button And Is Tracked")
    func testFollowingAProfileFlipsTheButtonAndIsTracked() async {
        let screen = makeScreen()
        screen.presenter.onViewAppear(delegate: profile("friend", following: []))
        #expect(!screen.presenter.isFollowing)
        #expect(!screen.presenter.isOwnProfile)

        screen.presenter.onFollowButtonPressed()
        await TestManagers.eventually { screen.presenter.isFollowing }

        screen.presenter.onFollowButtonPressed()
        await TestManagers.eventually { !screen.presenter.isFollowing }

        #expect(screen.interactor.trackedEventNames == [
            "SocialProfileView_Follow_Pressed", "SocialProfileView_Unfollow_Pressed"
        ])
        #expect(screen.router.alertTitles.isEmpty)
    }

    @Test("Test The Readers Own Profile Has No Follow Button")
    func testTheReadersOwnProfileHasNoFollowButton() {
        let screen = makeScreen()
        screen.presenter.onViewAppear(delegate: profile("me", following: []))

        #expect(screen.presenter.isOwnProfile)
    }

    /// A failed follow leaves the button where it was and says so, rather than silently pretending.
    @Test("Test A Failed Follow Shows An Alert And Leaves The Button")
    func testAFailedFollowShowsAnAlertAndLeavesTheButton() async {
        let screen = makeScreen()
        screen.interactor.followError = DashboardTestError.failed
        screen.presenter.onViewAppear(delegate: profile("friend", following: []))

        screen.presenter.onFollowButtonPressed()
        await TestManagers.eventually { !screen.router.alertTitles.isEmpty }

        #expect(screen.router.alertTitles == ["Unable to follow user"])
        #expect(!screen.presenter.isFollowing)
    }

    private func privateProfile(_ id: String, following: [String] = []) -> SocialProfileDelegate {
        SocialProfileDelegate(user: UserModel(userId: id, followingIds: following, isPrivate: true))
    }

    /// Instagram's rule: a private profile is open to its owner and its followers, and locked to
    /// everyone else — including someone the profile follows but who does not follow it back.
    @Test("Test A Private Profile Is Open Only To Its Owner And Followers")
    func testAPrivateProfileIsOpenOnlyToItsOwnerAndFollowers() {
        let screen = makeScreen()

        screen.presenter.onViewAppear(delegate: privateProfile("friend"))
        #expect(screen.presenter.isLocked)
        screen.presenter.onFollowersPressed()
        screen.presenter.onFollowingPressed()
        #expect(screen.router.followersDelegates.isEmpty)

        // The profile following the reader is not the reader following the profile.
        screen.presenter.onViewAppear(delegate: privateProfile("friend", following: ["me"]))
        #expect(screen.presenter.isLocked)

        screen.interactor.currentUser = UserModel(userId: "me", followingIds: ["friend"])
        screen.presenter.onViewAppear(delegate: privateProfile("friend"))
        #expect(!screen.presenter.isLocked)

        screen.presenter.onViewAppear(delegate: privateProfile("me"))
        #expect(!screen.presenter.isLocked)

        screen.presenter.onViewAppear(delegate: profile("stranger", following: []))
        #expect(!screen.presenter.isLocked)
    }

    /// A pending request does not open the profile; only the follow the accepted request becomes does.
    @Test("Test A Pending Request Keeps A Private Profile Locked")
    func testAPendingRequestKeepsAPrivateProfileLocked() {
        let screen = makeScreen()
        screen.interactor.sentFollowRequestIds = ["friend"]

        screen.presenter.onViewAppear(delegate: privateProfile("friend"))

        #expect(screen.presenter.followState == .requested)
        #expect(screen.presenter.isLocked)
    }

    /// Following a public profile is immediate; following a private one sends a request, the
    /// button reads Requested, and tapping it again takes the request back.
    @Test("Test Following A Private Profile Requests And Tapping Again Cancels")
    func testFollowingAPrivateProfileRequestsAndTappingAgainCancels() async {
        let screen = makeScreen()
        screen.presenter.onViewAppear(delegate: privateProfile("friend"))
        #expect(screen.presenter.followState == .follow)

        screen.presenter.onFollowButtonPressed()
        await TestManagers.eventually { screen.presenter.followState == .requested }
        #expect(!screen.presenter.isFollowing)
        #expect(screen.interactor.currentUser?.followingIds?.contains("friend") != true)

        screen.presenter.onFollowButtonPressed()
        await TestManagers.eventually { screen.presenter.followState == .follow }

        #expect(screen.interactor.sentFollowRequestIds.isEmpty)
        #expect(screen.interactor.trackedEventNames == [
            "SocialProfileView_Follow_Pressed", "SocialProfileView_CancelRequest_Pressed"
        ])
    }

    @Test("Test Following A Public Profile Is Immediate")
    func testFollowingAPublicProfileIsImmediate() async {
        let screen = makeScreen()
        screen.presenter.onViewAppear(delegate: profile("friend", following: []))

        screen.presenter.onFollowButtonPressed()
        await TestManagers.eventually { screen.presenter.followState == .following }

        #expect(screen.interactor.sentFollowRequestIds.isEmpty)
    }

    /// "Follows you" is the profile's following list naming the reader — never shown on the
    /// reader's own profile, and not implied by the reader following them.
    @Test("Test Follows You Reads The Profiles Following List")
    func testFollowsYouReadsTheProfilesFollowingList() {
        let screen = makeScreen()

        screen.presenter.onViewAppear(delegate: profile("friend", following: ["me"]))
        #expect(screen.presenter.followsYou)

        screen.interactor.currentUser = UserModel(userId: "me", followingIds: ["friend"])
        screen.presenter.onViewAppear(delegate: profile("friend", following: ["someone"]))
        #expect(!screen.presenter.followsYou)

        screen.presenter.onViewAppear(delegate: profile("me", following: ["me"]))
        #expect(!screen.presenter.followsYou)
    }

    /// The Following stat opens the same list screen, filled with the profile's own following.
    @Test("Test The Following Stat Opens The Profiles Following List")
    func testTheFollowingStatOpensTheProfilesFollowingList() async {
        let screen = makeScreen()
        screen.interactor.usersById = ["a": DashboardFixture.user("a"), "b": DashboardFixture.user("b")]
        screen.presenter.onViewAppear(delegate: profile("friend", following: ["a", "b"]))

        screen.presenter.onFollowingPressed()
        await TestManagers.eventually { !screen.router.followersDelegates.isEmpty }

        #expect(screen.interactor.fetchedUserIds == [["a", "b"]])
        #expect(screen.router.followersDelegates.first?.title == "Following")
        #expect(screen.router.followersDelegates.first?.followers.map(\.userId) == ["a", "b"])
    }

    // MARK: Sessions

    /// Someone else's sessions are fetched for their user id; a locked profile fetches nothing and
    /// shows nothing, even if sessions were somehow to hand.
    @Test("Test Appearing Fetches Sessions For The Profile And Never For A Locked One")
    func testAppearingFetchesSessionsForTheProfileAndNeverForALockedOne() async {
        let screen = makeScreen()
        screen.interactor.remoteSessions = [DashboardFixture.session(id: "s1", author: "friend", on: DashboardFixture.date(day: 2))]

        screen.presenter.onViewAppear(delegate: profile("friend", following: []))
        await TestManagers.eventually { !screen.presenter.sessions.isEmpty }
        #expect(screen.interactor.fetchedSessionAuthorIds == ["friend"])
        #expect(screen.presenter.sessions.map(\.id) == ["s1"])

        let locked = makeScreen()
        locked.interactor.remoteSessions = screen.interactor.remoteSessions
        locked.presenter.onViewAppear(delegate: privateProfile("stranger", following: ["me"]))
        await TestManagers.eventually { !locked.interactor.fetchedFollowerIds.isEmpty }
        #expect(locked.interactor.fetchedSessionAuthorIds.isEmpty)
        #expect(locked.presenter.sessions.isEmpty)
    }

    /// The reader's own profile reads the local history instead of going to the network.
    @Test("Test The Readers Own Profile Reads Local Sessions")
    func testTheReadersOwnProfileReadsLocalSessions() async {
        let screen = makeScreen()
        screen.interactor.workoutSessions = [DashboardFixture.session(id: "mine", on: DashboardFixture.date(day: 3))]

        screen.presenter.onViewAppear(delegate: profile("me", following: []))
        await TestManagers.eventually { !screen.interactor.fetchedFollowerIds.isEmpty }

        #expect(screen.interactor.fetchedSessionAuthorIds.isEmpty)
        #expect(screen.presenter.sessions.map(\.id) == ["mine"])
    }

    /// Only finished, non-rest sessions are shown, newest first.
    @Test("Test Unfinished And Rest Sessions Are Excluded And Newest Comes First")
    func testUnfinishedAndRestSessionsAreExcludedAndNewestComesFirst() {
        let screen = makeScreen()
        screen.interactor.workoutSessions = [
            DashboardFixture.session(id: "old", on: DashboardFixture.date(day: 1)),
            DashboardFixture.session(id: "open", on: DashboardFixture.date(day: 5), finished: false),
            DashboardFixture.session(id: "rest", on: DashboardFixture.date(day: 6), isRestDay: true),
            DashboardFixture.session(id: "new", on: DashboardFixture.date(day: 4))
        ]

        screen.presenter.onViewAppear(delegate: profile("me", following: []))

        #expect(screen.presenter.sessions.map(\.id) == ["new", "old"])
    }

    /// Two sessions on one day are one training day; skipped and unfinished days are not days.
    @Test("Test Training Days Has One Entry Per Day With A Finished Session")
    func testTrainingDaysHasOneEntryPerDayWithAFinishedSession() {
        let screen = makeScreen()
        screen.interactor.workoutSessions = [
            DashboardFixture.session(id: "am", on: DashboardFixture.date(day: 2, hour: 7)),
            DashboardFixture.session(id: "pm", on: DashboardFixture.date(day: 2, hour: 18)),
            DashboardFixture.session(id: "next", on: DashboardFixture.date(day: 3)),
            DashboardFixture.session(id: "open", on: DashboardFixture.date(day: 4), finished: false),
            DashboardFixture.session(id: "rest", on: DashboardFixture.date(day: 5), isRestDay: true)
        ]

        screen.presenter.onViewAppear(delegate: profile("me", following: []))

        let calendar = Calendar.current
        #expect(screen.presenter.trainingDays == [
            calendar.startOfDay(for: DashboardFixture.date(day: 2)),
            calendar.startOfDay(for: DashboardFixture.date(day: 3))
        ])
    }

    /// The program line names the reader's own program, and nobody else's without a fetch.
    @Test("Test The Program Line Shows Only On The Readers Own Profile")
    func testTheProgramLineShowsOnlyOnTheReadersOwnProfile() {
        let screen = makeScreen()
        screen.interactor.activeTrainingProgram = TrainingProgram(authorId: "me", name: "5/3/1", icon: "dumbbell", colour: "blue")

        screen.presenter.onViewAppear(delegate: profile("me", following: []))
        #expect(screen.presenter.programName == "5/3/1")

        screen.presenter.onViewAppear(delegate: profile("friend", following: []))
        #expect(screen.presenter.programName == nil)
    }

    @Test("Test Leaving The Profile Is Tracked")
    func testLeavingTheProfileIsTracked() {
        let screen = makeScreen()

        screen.presenter.onViewDisappear(delegate: profile("friend", following: []))

        #expect(screen.interactor.trackedEventNames == ["SocialProfileView_Disappear"])
    }

    // MARK: Blocking and reporting

    /// Blocking asks first, since it also unfollows and hides the person everywhere. Nothing is
    /// written until the reader confirms.
    @Test("Test Blocking Asks For Confirmation Then Blocks")
    func testBlockingAsksForConfirmationThenBlocks() async {
        let screen = makeScreen()
        screen.presenter.onViewAppear(delegate: SocialProfileDelegate(user: UserModel(userId: "friend", submittedFirstName: "Sam")))
        #expect(screen.presenter.blockMenuTitle == "Block Sam")

        screen.presenter.onBlockMenuPressed()
        #expect(screen.router.alertTitles == ["Block Sam?"])
        #expect(screen.interactor.blockedIds.isEmpty)

        screen.presenter.onBlockConfirmed()
        await TestManagers.eventually { screen.presenter.isBlocked }

        #expect(screen.interactor.blockedIds == ["friend"])
        #expect(screen.presenter.blockMenuTitle == "Unblock")
        #expect(screen.presenter.showsFollowButton == false)
    }

    @Test("Test Blocking A Followed Profile Unfollows It")
    func testBlockingAFollowedProfileUnfollowsIt() async {
        let screen = makeScreen()
        screen.interactor.currentUser = UserModel(userId: "me", followingIds: ["friend"])
        screen.presenter.onViewAppear(delegate: profile("friend", following: []))
        #expect(screen.presenter.isFollowing)

        screen.presenter.onBlockConfirmed()
        await TestManagers.eventually { screen.presenter.isBlocked }

        #expect(!screen.presenter.isFollowing)
    }

    /// Unblocking is not destructive, so it goes straight through.
    @Test("Test Unblocking Needs No Confirmation")
    func testUnblockingNeedsNoConfirmation() async {
        let screen = makeScreen()
        screen.interactor.currentUser = UserModel(userId: "me", blockedUserIds: ["friend"])
        screen.presenter.onViewAppear(delegate: profile("friend", following: []))

        screen.presenter.onBlockMenuPressed()
        await TestManagers.eventually { !screen.presenter.isBlocked }

        #expect(screen.interactor.unblockedIds == ["friend"])
        #expect(screen.router.alertTitles.isEmpty)
    }

    @Test("Test Reporting A Profile Sends The User")
    func testReportingAProfileSendsTheUser() async {
        let screen = makeScreen()
        screen.presenter.onViewAppear(delegate: profile("friend", following: []))

        screen.presenter.onReportPressed()
        #expect(screen.router.alertTitles == ["Report Profile"])
        #expect(screen.interactor.reports.isEmpty)

        screen.presenter.reportFlow.onReasonSelected(.harassment)
        screen.presenter.reportFlow.onSendPressed()
        await TestManagers.eventually { !screen.interactor.reports.isEmpty }

        #expect(screen.interactor.reports == ["user|friend|friend|harassment"])
    }
}

// MARK: - Followers list

/// The people and the title travel in the delegate; the presenter only answers who the reader
/// already follows and forwards the button presses.
@MainActor
struct SocialFollowersListTests {

    private final class Interactor: SpyGlobalInteractor, FollowersListInteractor {
        var currentUser: UserModel? = UserModel(userId: "me", followingIds: ["a"])
        var followError: Error?
        private(set) var followed: [String] = []
        private(set) var unfollowed: [String] = []
        var sentFollowRequestIds: Set<String> = ["pending"]
        private(set) var requested: [String] = []
        private(set) var cancelled: [String] = []

        func sendFollowRequest(to user: UserModel) async throws { requested.append(user.userId) }
        func cancelFollowRequest(userId: String) async throws { cancelled.append(userId) }

        func followUser(userId: String) async throws {
            if let followError { throw followError }
            followed.append(userId)
        }
        func unfollowUser(userId: String) async throws {
            if let followError { throw followError }
            unfollowed.append(userId)
        }
        func removeFollower(userId: String) async throws { }
    }

    private final class Router: FollowersListRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var alertTitles: [String] = []
        private(set) var profileUserIds: [String] = []

        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) {
            alertTitles.append(title)
        }
        func showSimpleAlert(title: String, subtitle: String?) {
            alertTitles.append(title)
        }
        func showSocialProfileView(delegate: SocialProfileDelegate) {
            profileUserIds.append(delegate.user.userId)
        }
    }

    @Test("Test The Followers List Defaults To The Followers Title")
    func testTheFollowersListDefaultsToTheFollowersTitle() {
        let delegate = FollowersListDelegate(followers: [DashboardFixture.user("a")])

        #expect(delegate.title == "Followers")
        #expect(delegate.followers.map(\.userId) == ["a"])
    }

    /// Each row's button reads the reader's list, and the reader's own row has none.
    @Test("Test Rows Know Who The Reader Follows And Skip The Reader")
    func testRowsKnowWhoTheReaderFollowsAndSkipTheReader() {
        let presenter = FollowersListPresenter(interactor: Interactor(), router: Router())

        #expect(presenter.followState(for: DashboardFixture.user("a")) == .following)
        #expect(presenter.followState(for: DashboardFixture.user("b")) == .follow)
        #expect(presenter.followState(for: DashboardFixture.user("pending")) == .requested)
        #expect(presenter.showsFollowButton(for: DashboardFixture.user("b")))
        #expect(!presenter.showsFollowButton(for: DashboardFixture.user("me")))
    }

    @Test("Test Each Button State Reaches The Interactor And A Row Opens The Profile")
    func testEachButtonStateReachesTheInteractorAndARowOpensTheProfile() async {
        let interactor = Interactor()
        let router = Router()
        let presenter = FollowersListPresenter(interactor: interactor, router: router)

        presenter.onFollowButtonPressed(user: DashboardFixture.user("b"))
        presenter.onFollowButtonPressed(user: DashboardFixture.user("a"))
        presenter.onFollowButtonPressed(user: UserModel(userId: "private", isPrivate: true))
        presenter.onFollowButtonPressed(user: DashboardFixture.user("pending"))
        presenter.onUserPressed(user: DashboardFixture.user("b"))
        await TestManagers.eventually { !interactor.unfollowed.isEmpty && !interactor.cancelled.isEmpty && !interactor.requested.isEmpty }

        #expect(interactor.followed == ["b"])
        #expect(interactor.unfollowed == ["a"])
        #expect(interactor.requested == ["private"])
        #expect(interactor.cancelled == ["pending"])
        #expect(router.profileUserIds == ["b"])
    }

    @Test("Test A Failed Follow From The List Shows An Alert")
    func testAFailedFollowFromTheListShowsAnAlert() async {
        let interactor = Interactor()
        interactor.followError = DashboardTestError.failed
        let router = Router()
        let presenter = FollowersListPresenter(interactor: interactor, router: router)

        presenter.onFollowButtonPressed(user: DashboardFixture.user("b"))
        await TestManagers.eventually { !router.alertTitles.isEmpty }

        #expect(router.alertTitles == ["Unable to follow user"])
    }
}
