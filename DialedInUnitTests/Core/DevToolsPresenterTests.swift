//
//  DevToolsPresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
import UserNotifications
@testable import DialedIn

enum DevToolsTestError: Error { case failed }

// MARK: - Dev settings

/// The developer menu. Nothing here ships to a user, but two of its buttons decide what a
/// developer or tester believes about the app, and both can be wrong silently.
///
/// The reseed buttons are the sharp ones. Seeding is guarded by UserDefaults flags whose names are
/// versioned — `hasSeededPrebuiltExercisesV2`, not `hasSeededPrebuiltExercises` — and a reset that
/// cleared the un-suffixed name would report "Complete! Restart app to reseed", change nothing,
/// and send whoever pressed it off hunting a bug in the seeding code instead. The tests below
/// check the exact keys the managers actually read.
///
/// The A/B overrides are the other: a toggle that fails to save has to snap back, or the menu says
/// the app is in one variant while it is running the other.
///
/// Serialized because the reseed tests read and write the real `UserDefaults.standard` — the
/// presenter names those keys literally, so there is nowhere else to put them — and run in
/// parallel they would clear each other's flags and disagree about which library was reset.
@Suite(.serialized)
@MainActor
struct DevToolsSettingsPresenterTests {

    // MARK: - Doubles

    private final class Interactor: SpyGlobalInteractor, DevSettingsInteractor {
        var auth: UserAuthInfo?
        var currentUser: UserModel?
        var activeTests = ActiveABTests(notificationsTest: false, paywallTest: .custom)
        var activeSession: WorkoutSessionModel?
        var workoutSessions: [WorkoutSessionModel] = []
        var userExercises: [ExerciseModel] = []
        var systemExercises: [ExerciseModel] = []
        var allExercises: [ExerciseModel] = []
        var userWorkoutTemplates: [WorkoutTemplateModel] = []
        var systemWorkoutTemplates: [WorkoutTemplateModel] = []
        var allWorkoutTemplates: [WorkoutTemplateModel] = []

        var overrideError: Error?
        var fetchedSession: WorkoutSessionModel?
        var fetchError: Error?
        var signOutError: Error?

        private(set) var overrides: [ActiveABTests] = []
        private(set) var requestedSessionIds: [String] = []
        private(set) var didSignOut = false

        func override(updatedTests: ActiveABTests) throws {
            if let overrideError { throw overrideError }
            overrides.append(updatedTests)
            activeTests = updatedTests
        }

        func getWorkoutSession(id: String) async throws -> WorkoutSessionModel {
            requestedSessionIds.append(id)
            if let fetchError { throw fetchError }
            guard let fetchedSession else { throw DevToolsTestError.failed }
            return fetchedSession
        }

        func signOut() async throws {
            if let signOutError { throw signOutError }
            didSignOut = true
        }
    }

    private final class Router: DevSettingsRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var alertedErrors: [Error] = []
        private(set) var didSwitchToOnboarding = false

        func showAlert(error: Error) { alertedErrors.append(error) }
        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) { }
        func showSimpleAlert(title: String, subtitle: String?) { }

        func switchToOnboardingModule() { didSwitchToOnboarding = true }
    }

    private struct Screen {
        let presenter: DevSettingsPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen() -> Screen {
        let interactor = Interactor()
        let router = Router()
        return Screen(
            presenter: DevSettingsPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    /// The exact names the seeding code reads. Spelled out here rather than referenced so that a
    /// rename in one place and not the other shows up as a failing test.
    private enum SeedingKey {
        static let exercisesSeeded = "hasSeededPrebuiltExercisesV2"
        static let exercisesVersion = "prebuiltExercisesSeedingVersionV2"
        static let workoutsSeeded = "hasSeededPrebuiltWorkouts"
        static let workoutsVersion = "prebuiltWorkoutsSeedingVersion"
        static let programsSeeded = "hasSeededPrebuiltPrograms"
        static let programsVersion = "prebuiltProgramsSeedingVersion"
        static let all = [exercisesSeeded, exercisesVersion, workoutsSeeded, workoutsVersion, programsSeeded, programsVersion]
    }

    /// Marks every seeding flag as already done, and hands back a closure that puts the defaults
    /// back as they were — other suites share this simulator's `UserDefaults`.
    private func markEverythingSeeded() -> () -> Void {
        let previous = SeedingKey.all.map { ($0, UserDefaults.standard.object(forKey: $0)) }
        UserDefaults.standard.set(true, forKey: SeedingKey.exercisesSeeded)
        UserDefaults.standard.set(9, forKey: SeedingKey.exercisesVersion)
        UserDefaults.standard.set(true, forKey: SeedingKey.workoutsSeeded)
        UserDefaults.standard.set(9, forKey: SeedingKey.workoutsVersion)
        UserDefaults.standard.set(true, forKey: SeedingKey.programsSeeded)
        UserDefaults.standard.set(9, forKey: SeedingKey.programsVersion)
        return {
            for (key, value) in previous {
                if let value {
                    UserDefaults.standard.set(value, forKey: key)
                } else {
                    UserDefaults.standard.removeObject(forKey: key)
                }
            }
        }
    }

    private func isSeeded(_ key: String) -> Bool {
        UserDefaults.standard.object(forKey: key) != nil
    }

    // MARK: - Reseeding

    /// "Reset exercises" has to clear the versioned keys, because those are the ones
    /// `ExerciseModelManager` checks. Clearing anything else leaves the library exactly as it was
    /// while telling the tester it has been reset.
    @Test("Test Resetting Exercises Clears The Versioned Exercise Keys")
    func testResettingExercisesClearsTheVersionedExerciseKeys() async {
        let restore = markEverythingSeeded()
        defer { restore() }
        let screen = makeScreen()

        await screen.presenter.resetExerciseSeeding()

        #expect(!isSeeded(SeedingKey.exercisesSeeded))
        #expect(!isSeeded(SeedingKey.exercisesVersion))
        // Only the exercises: a tester resetting one library should not lose the other.
        #expect(isSeeded(SeedingKey.workoutsSeeded))
        #expect(isSeeded(SeedingKey.workoutsVersion))
    }

    /// The same for workouts, and the same reason: these are the keys `WorkoutTemplateManager`
    /// reads.
    @Test("Test Resetting Workouts Clears Only The Workout Keys")
    func testResettingWorkoutsClearsOnlyTheWorkoutKeys() async {
        let restore = markEverythingSeeded()
        defer { restore() }
        let screen = makeScreen()

        await screen.presenter.resetWorkoutSeeding()

        #expect(!isSeeded(SeedingKey.workoutsSeeded))
        #expect(!isSeeded(SeedingKey.workoutsVersion))
        #expect(isSeeded(SeedingKey.exercisesSeeded))
        #expect(isSeeded(SeedingKey.exercisesVersion))
    }

    /// The same for programs: these are the keys `TrainingProgramManager` reads.
    @Test("Test Resetting Programs Clears Only The Program Keys")
    func testResettingProgramsClearsOnlyTheProgramKeys() async {
        let restore = markEverythingSeeded()
        defer { restore() }
        let screen = makeScreen()

        await screen.presenter.resetProgramSeeding()

        #expect(!isSeeded(SeedingKey.programsSeeded))
        #expect(!isSeeded(SeedingKey.programsVersion))
        #expect(isSeeded(SeedingKey.workoutsSeeded))
        #expect(isSeeded(SeedingKey.exercisesSeeded))
    }

    /// "Reset all" means all four. Workouts reference exercises by id, so half a reset leaves
    /// templates pointing at an exercise library that is about to be rebuilt.
    @Test("Test Resetting Everything Clears All Four Seeding Keys")
    func testResettingEverythingClearsAllFourSeedingKeys() async {
        let restore = markEverythingSeeded()
        defer { restore() }
        let screen = makeScreen()

        await screen.presenter.resetAllSeeding()

        for key in SeedingKey.all {
            #expect(!isSeeded(key))
        }
    }

    /// The button finishes rather than leaving the menu stuck saying "Resetting…" — the message is
    /// the only feedback a tester gets that anything happened.
    @Test("Test A Reset Finishes And Clears Its Own Message")
    func testAResetFinishesAndClearsItsOwnMessage() async {
        let restore = markEverythingSeeded()
        defer { restore() }
        let screen = makeScreen()
        #expect(!screen.presenter.isReseeding)

        await screen.presenter.resetAllSeeding()

        #expect(!screen.presenter.isReseeding)
        #expect(screen.presenter.reseedingMessage.isEmpty)
    }

    // MARK: - A/B overrides

    /// The menu shows what is actually in force, read on appear rather than assumed.
    @Test("Test The Menu Loads The Tests Currently In Force")
    func testTheMenuLoadsTheTestsCurrentlyInForce() {
        let screen = makeScreen()
        screen.interactor.activeTests = ActiveABTests(notificationsTest: true, paywallTest: .revenueCat)

        screen.presenter.loadABTests()

        #expect(screen.presenter.isInNotificationsABTest)
        #expect(screen.presenter.paywallTest == .revenueCat)
    }

    /// Flipping a toggle overrides the test for real.
    @Test("Test Changing A Toggle Overrides The Test")
    func testChangingAToggleOverridesTheTest() {
        let screen = makeScreen()

        screen.presenter.handleNotificationTestChange(oldValue: false, newValue: true)

        #expect(screen.interactor.overrides.count == 1)
        #expect(screen.interactor.activeTests.notificationsTest)
    }

    /// Picking the variant that is already in force writes nothing. Overriding is persisted, so a
    /// no-op write is a needless one.
    @Test("Test Choosing The Variant Already In Force Writes Nothing")
    func testChoosingTheVariantAlreadyInForceWritesNothing() {
        let screen = makeScreen()
        screen.interactor.activeTests = ActiveABTests(notificationsTest: false, paywallTest: .custom)

        screen.presenter.handlePaywallOptionChange(oldValue: .custom, newValue: .custom)

        #expect(screen.interactor.overrides.isEmpty)
    }

    /// An override that cannot be saved snaps the control back and says so. Left alone, the menu
    /// would show a variant the app is not running, and every later reading of the screen would be
    /// a lie.
    @Test("Test A Failed Override Snaps Back And Reports")
    func testAFailedOverrideSnapsBackAndReports() {
        let screen = makeScreen()
        screen.interactor.activeTests = ActiveABTests(notificationsTest: false, paywallTest: .custom)
        screen.presenter.loadABTests()
        screen.interactor.overrideError = DevToolsTestError.failed

        screen.presenter.paywallTest = .storeKit
        screen.presenter.handlePaywallOptionChange(oldValue: .custom, newValue: .storeKit)

        #expect(screen.presenter.paywallTest == .custom)
        #expect(screen.router.alertedErrors.count == 1)
    }

    // MARK: - Fetching a session by id

    /// Looking up a session by id is how a developer checks what actually landed in Firestore.
    @Test("Test Fetching A Session By Id Shows What Came Back")
    func testFetchingASessionByIdShowsWhatCameBack() async {
        let screen = makeScreen()
        let session = WorkoutSessionModel.mock
        screen.interactor.fetchedSession = session
        screen.presenter.testSessionId = "session-1"

        await screen.presenter.fetchSessionFromFirebase()

        #expect(screen.presenter.fetchedSession?.id == session.id)
        #expect(screen.presenter.fetchError == nil)
        #expect(!screen.presenter.isFetchingSession)
        #expect(screen.interactor.requestedSessionIds == ["session-1"])
    }

    /// A lookup that fails shows the reason rather than an empty result that reads like "there is
    /// no such session".
    @Test("Test A Failed Lookup Shows The Reason Not An Empty Result")
    func testAFailedLookupShowsTheReasonNotAnEmptyResult() async {
        let screen = makeScreen()
        screen.interactor.fetchError = DevToolsTestError.failed
        screen.presenter.testSessionId = "missing"

        await screen.presenter.fetchSessionFromFirebase()

        #expect(screen.presenter.fetchedSession == nil)
        #expect(screen.presenter.fetchError != nil)
        #expect(!screen.presenter.isFetchingSession)
    }

    /// A second lookup clears the first one's result, so the screen never shows an old session
    /// beside a new id.
    @Test("Test A Second Lookup Does Not Keep The First Result")
    func testASecondLookupDoesNotKeepTheFirstResult() async {
        let screen = makeScreen()
        screen.interactor.fetchedSession = WorkoutSessionModel.mock
        screen.presenter.testSessionId = "session-1"
        await screen.presenter.fetchSessionFromFirebase()
        #expect(screen.presenter.fetchedSession != nil)

        screen.interactor.fetchError = DevToolsTestError.failed
        screen.presenter.testSessionId = "missing"
        await screen.presenter.fetchSessionFromFirebase()

        #expect(screen.presenter.fetchedSession == nil)
    }

    // MARK: - Forcing a fresh anonymous user

    /// The point of the button is to end up somewhere a brand-new install would be, so signing out
    /// and switching to onboarding have to both happen — signing out alone would leave the app
    /// sitting in the tab bar with nobody behind it.
    @Test("Test Forcing A Fresh User Signs Out And Restarts Onboarding")
    func testForcingAFreshUserSignsOutAndRestartsOnboarding() async {
        let screen = makeScreen()

        screen.presenter.onForceFreshAnonUser()

        #expect(await TestManagers.eventually(timeout: .seconds(5)) { screen.router.didSwitchToOnboarding })
        #expect(screen.interactor.didSignOut)
        #expect(screen.interactor.trackedEventNames.contains("DevSettingsView_ForceSignOut_Success"))
    }

    /// A sign-out that fails does not pretend to have worked and does not restart onboarding on top
    /// of a user who is still signed in.
    @Test("Test A Failed Force Sign Out Does Not Restart Onboarding")
    func testAFailedForceSignOutDoesNotRestartOnboarding() async {
        let screen = makeScreen()
        screen.interactor.signOutError = DevToolsTestError.failed

        screen.presenter.onForceFreshAnonUser()

        #expect(await TestManagers.eventually { screen.router.alertedErrors.count == 1 })
        #expect(!screen.router.didSwitchToOnboarding)
        #expect(screen.interactor.trackedEventNames.contains("DevSettingsView_ForceSignOut_Fail"))
    }

    // MARK: - Read-outs

    /// The parameter dumps are alphabetical so a developer can scan them; an unsorted dump of forty
    /// keys is unreadable. With nobody signed in they are empty rather than crashing.
    @Test("Test The Parameter Dumps Are Sorted And Empty When Absent")
    func testTheParameterDumpsAreSortedAndEmptyWhenAbsent() {
        let screen = makeScreen()
        #expect(screen.presenter.authParams().isEmpty)
        #expect(screen.presenter.userParams().isEmpty)

        screen.interactor.auth = UserAuthInfo(uid: "user-1", email: "a@b.com", isAnonymous: false)

        let keys = screen.presenter.authParams().map(\.key)
        #expect(!keys.isEmpty)
        #expect(keys == keys.sorted())
        #expect(screen.presenter.deviceParams().map(\.key) == screen.presenter.deviceParams().map(\.key).sorted())
    }

    @Test("Test The Dev Menu Tracks Its Own Lifecycle")
    func testTheDevMenuTracksItsOwnLifecycle() {
        let screen = makeScreen()

        screen.presenter.onViewAppear()
        screen.presenter.onViewDisappear()

        #expect(screen.interactor.trackedScreenEventNames == ["DevSettingsView_Appear"])
        #expect(screen.interactor.trackedEventNames == ["DevSettingsView_Disappear"])
    }
}

// MARK: - Notifications

/// The notifications screen: the list of likes and comments, and the permission prompt that
/// decides whether any of them ever arrive as a push.
///
/// Opening the list is what marks activity as read, so the badge and the delivered notifications
/// have to be cleared together — a list that shows everything as read while the badge still says
/// three is the visible symptom of missing one of them.
///
/// The permission request used to swallow its error entirely. A user who taps "Turn on
/// notifications" and sees nothing happen has no way to tell a refusal from a bug, so the failure
/// is asserted here.
@MainActor
struct DevToolsNotificationsPresenterTests {

    private final class Interactor: SpyGlobalInteractor, NotificationsInteractor {
        var isAuthorised: UNAuthorizationStatus = .notDetermined
        var activityNotifications: [ActivityNotificationModel] = []

        var requestError: Error?
        var requestResult = true
        var checkError: Error?
        var fetchError: Error?
        var markReadError: Error?

        private(set) var fetchCount = 0
        private(set) var markReadCount = 0
        private(set) var clearDeliveredCount = 0
        private(set) var requestCount = 0
        private(set) var deletedIds: [String] = []

        func requestPushAuthorisation() async throws -> Bool {
            requestCount += 1
            if let requestError { throw requestError }
            return requestResult
        }

        func canRequestNotificationAuthorisation() async -> Bool { true }

        func removeDeliveredNotifications(ids: [String]) { }

        func checkPushNotificationAuthorisation() async throws -> UNAuthorizationStatus {
            if let checkError { throw checkError }
            return isAuthorised
        }

        func fetchActivityNotifications() async throws {
            fetchCount += 1
            if let fetchError { throw fetchError }
        }

        func markActivityNotificationsRead() async throws {
            markReadCount += 1
            if let markReadError { throw markReadError }
        }

        func deleteActivityNotification(id: String) async throws { deletedIds.append(id) }

        func clearAllDeliveredNotifications() { clearDeliveredCount += 1 }

        var privateUserSettings = PrivateUserSettings()
        // Follow requests and follow back are covered in `NotificationsFollowRequestTests`.
        var incomingFollowRequests: [FollowRequestModel] = []
        var sentFollowRequestIds: Set<String> = []
        func fetchIncomingFollowRequests() async throws { }
        func respondToFollowRequest(requesterId: String, accept: Bool) async throws { }
        func getUser(userId: String) async throws -> UserModel { UserModel(userId: userId) }
        func followUser(userId: String) async throws { }
        func unfollowUser(userId: String) async throws { }
        func sendFollowRequest(to user: UserModel) async throws { }
        func cancelFollowRequest(userId: String) async throws { }

        var currentUser: UserModel? = UserModel(userId: "user-1")
        var preferenceError: Error?
        private(set) var preferenceWrites: [String: Bool] = [:]

        /// Records the private-settings key the real `UserManager` would write, so a test can check
        /// the value lands under the field the Cloud Function reads.
        func updateSocialNotificationPreferences(type: ActivityNotificationModel.ActivityType, isEnabled: Bool) async throws {
            if let preferenceError { throw preferenceError }
            preferenceWrites[PrivateUserSettings.socialPushKey(for: type).rawValue] = isEnabled
        }

        func fetchWorkoutSession(id: String, authorId: String) async throws -> WorkoutSessionModel { throw DevToolsTestError.failed }
        func fetchShare(id: String) async throws -> ShareModel { throw DevToolsTestError.failed }
        func fetchChallenge(id: String) async throws -> ChallengeModel { throw DevToolsTestError.failed }
        func updatePrivateUserSettings(_ change: (inout PrivateUserSettings) -> Void) async throws { change(&privateUserSettings) }

        // MARK: - GroupedNotifications
        var canLoadMoreActivityNotifications = false
        func fetchMoreActivityNotifications() async throws { }
        func markActivityNotificationsRead(ids: [String]) async throws { }
    }

    private final class Router: NotificationsRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var alertedErrors: [Error] = []

        func showAlert(error: Error) { alertedErrors.append(error) }
        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) { }
        func showSimpleAlert(title: String, subtitle: String?) { }
        func showWorkoutSessionDetailView(delegate: WorkoutSessionDetailDelegate) { }
        func showWorkoutSessionThread(delegate: WorkoutSessionDetailDelegate) { }
        func showSocialProfileView(delegate: SocialProfileDelegate) { }
        func showSharedItemView(delegate: SharedItemDelegate) { }
        func showChallengeDetailView(delegate: ChallengeDetailDelegate) { }
    }

    private struct Screen {
        let presenter: NotificationsPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen() -> Screen {
        let interactor = Interactor()
        let router = Router()
        return Screen(
            presenter: NotificationsPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    private func activity(id: String) -> ActivityNotificationModel {
        ActivityNotificationModel(
            id: id,
            type: .comment,
            actorId: "actor-1",
            actorName: "Jane",
            actorImageUrl: nil,
            sessionId: "session-1",
            sessionAuthorId: "user-1",
            commentText: "Nice session",
            dateCreated: Date(timeIntervalSince1970: 0),
            isRead: false
        )
    }

    // MARK: - Opening the list

    /// Opening the list fetches, marks read and clears what iOS has already delivered — all three,
    /// because the badge and the list are separate counts of the same thing.
    @Test("Test Opening The List Marks Read And Clears The Badge")
    func testOpeningTheListMarksReadAndClearsTheBadge() async {
        let screen = makeScreen()
        screen.interactor.activityNotifications = [activity(id: "a")]

        await screen.presenter.loadNotifications()

        #expect(screen.interactor.fetchCount == 1)
        #expect(screen.interactor.markReadCount == 1)
        #expect(screen.interactor.clearDeliveredCount == 1)
        #expect(!screen.presenter.isLoading)
        #expect(screen.presenter.activityNotifications.count == 1)
    }

    /// A fetch that fails still stops the spinner and still clears what was delivered, so the
    /// screen shows an empty list rather than loading forever behind a badge that never goes away.
    @Test("Test A Failed Fetch Still Finishes Loading")
    func testAFailedFetchStillFinishesLoading() async {
        let screen = makeScreen()
        screen.interactor.fetchError = DevToolsTestError.failed

        await screen.presenter.loadNotifications()

        #expect(!screen.presenter.isLoading)
        #expect(screen.interactor.clearDeliveredCount == 1)
    }

    /// The screen starts out loading, so it shows a spinner rather than "no notifications" before
    /// anything has been fetched. Telling someone they have no activity when they might is worse
    /// than a moment of blankness.
    @Test("Test The List Starts Loading Not Empty")
    func testTheListStartsLoadingNotEmpty() {
        let screen = makeScreen()

        #expect(screen.presenter.isLoading)
    }

    // MARK: - Permission

    /// Granting permission loads the list straight away, so the screen behind the prompt is not
    /// left empty until the user backs out and returns.
    @Test("Test Granting Permission Loads The List Immediately")
    func testGrantingPermissionLoadsTheListImmediately() async {
        let screen = makeScreen()

        screen.presenter.onRequestNotificationsPressed()

        #expect(await TestManagers.eventually { screen.interactor.fetchCount == 1 })
        #expect(screen.interactor.requestCount == 1)
        #expect(screen.router.alertedErrors.isEmpty)
    }

    /// A permission request that throws tells the user. This catch used to be empty: the button
    /// did nothing visible and there was no way to tell a refusal from a failure.
    @Test("Test A Failed Permission Request Is Not Swallowed")
    func testAFailedPermissionRequestIsNotSwallowed() async {
        let screen = makeScreen()
        screen.interactor.requestError = DevToolsTestError.failed

        screen.presenter.onRequestNotificationsPressed()

        #expect(await TestManagers.eventually { screen.router.alertedErrors.count == 1 })
        #expect(screen.interactor.fetchCount == 0)
    }

    /// Checking the current status is how the screen decides between showing the list and showing
    /// the "turn these on" prompt, so a check that fails has to surface rather than leave the
    /// screen guessing.
    @Test("Test A Failed Permission Check Is Reported")
    func testAFailedPermissionCheckIsReported() async {
        let screen = makeScreen()
        screen.interactor.checkError = DevToolsTestError.failed

        await screen.presenter.checkPermissions()

        #expect(screen.router.alertedErrors.count == 1)
    }

    /// And a check that works reports nothing, so the screen only nags when something is wrong.
    @Test("Test A Successful Permission Check Says Nothing")
    func testASuccessfulPermissionCheckSaysNothing() async {
        let screen = makeScreen()
        screen.interactor.isAuthorised = .authorized

        await screen.presenter.checkPermissions()

        #expect(screen.router.alertedErrors.isEmpty)
        #expect(screen.presenter.authorizationStatus == .authorized)
    }

    // MARK: - Deleting

    /// Swiping a notification away deletes that one and no other.
    @Test("Test Deleting A Notification Deletes Only That One")
    func testDeletingANotificationDeletesOnlyThatOne() async {
        let screen = makeScreen()

        screen.presenter.onNotificationDeleted(activity(id: "a"))

        #expect(await TestManagers.eventually { screen.interactor.deletedIds == ["a"] })
    }

    @Test("Test The Notifications Screen Tracks Its Own Lifecycle")
    func testTheNotificationsScreenTracksItsOwnLifecycle() {
        let screen = makeScreen()

        screen.presenter.onViewAppear()
        screen.presenter.onViewDisappear()
        // `dismissScreen()` is a statically dispatched extension, so the dismiss itself is invisible.
        screen.presenter.onDismissPressed()

        #expect(screen.interactor.trackedScreenEventNames == ["NotificationsView_Appear"])
        #expect(screen.interactor.trackedEventNames == ["NotificationsView_Disappear"])
    }

    // MARK: - Social push switches

    /// A user who has never written the private settings document has no preference fields, and
    /// must keep getting pushes: every switch reads on.
    @Test("Test Social Push Switches Default To On When The Private Settings Have No Preferences")
    func testSocialPushSwitchesDefaultToOnWhenThePrivateSettingsHaveNoPreferences() {
        let screen = makeScreen()
        #expect(screen.presenter.isLikesPushEnabled)
        #expect(screen.presenter.isCommentsPushEnabled)
        #expect(screen.presenter.isFollowsPushEnabled)
        #expect(screen.presenter.isNudgesPushEnabled)

        screen.interactor.privateUserSettings = PrivateUserSettings(socialPushLikes: false, socialPushFollows: true)
        #expect(!screen.presenter.isLikesPushEnabled)
        #expect(screen.presenter.isCommentsPushEnabled)
        #expect(screen.presenter.isFollowsPushEnabled)
    }

    /// Each switch writes its own key, and only that key, the moment it flips. The key names are
    /// the contract with `SOCIAL_PUSH_PREFERENCE_KEYS` in functions/lib.js.
    @Test("Test Flipping A Social Push Switch Writes Its Own Key")
    func testFlippingASocialPushSwitchWritesItsOwnKey() async {
        let screen = makeScreen()

        screen.presenter.isCommentsPushEnabled = false
        #expect(await TestManagers.eventually { screen.interactor.preferenceWrites == ["social_push_comments": false] })

        screen.presenter.isLikesPushEnabled = false
        screen.presenter.isFollowsPushEnabled = false
        screen.presenter.isNudgesPushEnabled = false
        let expected = ["social_push_comments": false, "social_push_likes": false, "social_push_follows": false, "social_push_nudges": false]
        #expect(await TestManagers.eventually { screen.interactor.preferenceWrites == expected })
        #expect(screen.interactor.trackedEventNames.contains("NotificationsView_SocialPush_Toggle"))
        #expect(screen.router.alertedErrors.isEmpty)
    }

    /// A write that fails says so, and the switch still reads the stored value rather than the
    /// one the user tried to set.
    @Test("Test A Failed Social Push Write Shows An Alert")
    func testAFailedSocialPushWriteShowsAnAlert() async {
        let screen = makeScreen()
        screen.interactor.preferenceError = DevToolsTestError.failed

        screen.presenter.isLikesPushEnabled = false

        #expect(await TestManagers.eventually { screen.router.alertedErrors.count == 1 })
        #expect(screen.interactor.preferenceWrites.isEmpty)
        #expect(screen.presenter.isLikesPushEnabled)
    }
}
