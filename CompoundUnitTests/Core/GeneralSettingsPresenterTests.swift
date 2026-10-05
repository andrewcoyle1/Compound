//
//  GeneralSettingsPresenterTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import SwiftUI
import AuthenticationServices
import Foundation
@testable import Compound

// MARK: - Customise Analytics

/// Which sections the Analytics tab draws. Stored as the hidden set, so a section added in a later
/// release shows up for everyone rather than being invisible to anyone who saved before it existed.
@MainActor
struct GeneralSettingsAnalyticsTests {

    private final class Interactor: SpyGlobalInteractor, CustomiseAnalyticsInteractor {
        var analyticsSettings = AnalyticsSettings(authorId: "user-1")
        private(set) var savedSettings: [AnalyticsSettings] = []

        func saveAnalyticsSettings(_ settings: AnalyticsSettings) async throws {
            savedSettings.append(settings)
            analyticsSettings = settings
        }
    }

    private final class Router: CustomiseAnalyticsRouter {
        let router: AnyRouter = TestRouting.anyRouter
    }

    private struct Screen {
        let presenter: CustomiseAnalyticsPresenter
        let interactor: Interactor
    }

    private func makeScreen(hidden: [AnalyticsSection] = []) -> Screen {
        let interactor = Interactor()
        interactor.analyticsSettings.hiddenSectionIds = hidden.map(\.rawValue)
        return Screen(
            presenter: CustomiseAnalyticsPresenter(interactor: interactor, router: Router()),
            interactor: interactor
        )
    }

    @Test("Test Every Section Starts Visible")
    func testEverySectionStartsVisible() {
        let screen = makeScreen()

        #expect(screen.presenter.sections.allSatisfy { screen.presenter.isVisible($0) })
        #expect(screen.presenter.hiddenCount == 0)
    }

    /// Hiding one section must not bring another back. The whole document is written on each
    /// change, so each save has to carry the hides that came before it.
    @Test("Test Hiding One Section Does Not Unhide Another")
    func testHidingOneSectionDoesNotUnhideAnother() async {
        let screen = makeScreen()

        screen.presenter.setVisible(false, for: .habits)
        screen.presenter.setVisible(false, for: .nutrition)
        screen.presenter.setVisible(false, for: .exercises)
        await TestManagers.eventually { screen.interactor.savedSettings.count == 3 }

        let saved = screen.interactor.savedSettings.last
        #expect(saved?.isVisible(.habits) == false)
        #expect(saved?.isVisible(.nutrition) == false)
        #expect(saved?.isVisible(.exercises) == false)
        #expect(saved?.isVisible(.bodyMetrics) == true)
        #expect(screen.presenter.hiddenCount == 3)
    }

    /// Hiding the same section twice must not record it twice, or Show All would have to run more
    /// than once to undo it.
    @Test("Test Hiding A Section Twice Records It Once")
    func testHidingASectionTwiceRecordsItOnce() async {
        let screen = makeScreen()

        screen.presenter.setVisible(false, for: .habits)
        screen.presenter.setVisible(false, for: .habits)
        await TestManagers.eventually { screen.interactor.savedSettings.count == 2 }

        #expect(screen.interactor.savedSettings.last?.hiddenSectionIds == [AnalyticsSection.habits.rawValue])
        #expect(screen.presenter.hiddenCount == 1)
    }

    /// Hiding everything would leave the tab with only its header, which reads as a broken screen
    /// rather than a customised one — so the last visible section cannot be switched off.
    @Test("Test The Last Visible Section Cannot Be Hidden")
    func testTheLastVisibleSectionCannotBeHidden() {
        let allButOne = AnalyticsSection.allCases.filter { $0 != .habits }
        let screen = makeScreen(hidden: allButOne)

        #expect(!screen.presenter.canHide(.habits))
        // A section that is already hidden is always switchable — that is how it comes back.
        #expect(screen.presenter.canHide(.nutrition))
    }

    @Test("Test A Section Can Be Hidden While Others Remain")
    func testASectionCanBeHiddenWhileOthersRemain() {
        let screen = makeScreen()

        #expect(screen.presenter.sections.allSatisfy { screen.presenter.canHide($0) })
    }

    /// Show All is the way back from any amount of hiding, in one press.
    @Test("Test Show All Brings Back Every Section At Once")
    func testShowAllBringsBackEverySectionAtOnce() async {
        let screen = makeScreen(hidden: [.habits, .nutrition, .exercises])

        screen.presenter.onShowAllPressed()
        await TestManagers.eventually { !screen.interactor.savedSettings.isEmpty }

        #expect(screen.presenter.hiddenCount == 0)
        #expect(screen.interactor.savedSettings.last?.hiddenSectionIds.isEmpty == true)
        #expect(screen.interactor.savedSettings.count == 1)
    }

    @Test("Test Changing A Section Is Tracked")
    func testChangingASectionIsTracked() {
        let screen = makeScreen()

        screen.presenter.setVisible(false, for: .habits)
        screen.presenter.onShowAllPressed()

        #expect(screen.interactor.trackedEventNames == [
            "CustomiseAnalyticsView_SectionVisibility_Changed",
            "CustomiseAnalyticsView_ShowAll_Press"
        ])
    }

    @Test("Test Appearing And Disappearing Are Tracked")
    func testAppearingAndDisappearingAreTracked() {
        let screen = makeScreen()

        screen.presenter.onViewAppear()
        screen.presenter.onViewDisappear()

        #expect(screen.interactor.trackedScreenEventNames == ["CustomiseAnalyticsView_Appear"])
        #expect(screen.interactor.trackedEventNames == ["CustomiseAnalyticsView_Disappear"])
    }
}

// MARK: - Units

/// Kilograms or pounds, centimetres or inches, kilometres or miles. Every number the app shows
/// passes through one of these, so the screen has to open on what the user actually chose and each
/// change has to persist without disturbing the other two.
@MainActor
struct GeneralSettingsUnitsTests {

    /// One write of all three preferences, as the interactor takes them.
    private struct UnitWrite {
        let length: LengthUnitPreference
        let weight: WeightUnitPreference
        let distance: DistanceUnitPreference
    }

    private final class Interactor: SpyGlobalInteractor, UnitsInteractor {
        var currentUser: UserModel?
        private(set) var saved: [UnitWrite] = []

        func updateUnitPreferences(
            length: LengthUnitPreference,
            weight: WeightUnitPreference,
            distance: DistanceUnitPreference
        ) async throws {
            saved.append(UnitWrite(length: length, weight: weight, distance: distance))
        }
    }

    private final class Router: UnitsRouter {
        let router: AnyRouter = TestRouting.anyRouter
    }

    private struct Screen {
        let presenter: UnitsPresenter
        let interactor: Interactor
    }

    private func makeScreen(user: UserModel?, locale: Locale = Locale(identifier: "de_DE")) -> Screen {
        let interactor = Interactor()
        interactor.currentUser = user
        return Screen(
            presenter: UnitsPresenter(interactor: interactor, router: Router(), locale: locale),
            interactor: interactor
        )
    }

    /// The screen has to show what is stored. Showing a default over the top of a real preference
    /// would silently re-save metric for someone who chose imperial.
    @Test("Test The Screen Opens On The Stored Preferences")
    func testTheScreenOpensOnTheStoredPreferences() {
        let screen = makeScreen(user: UserModel(
            userId: "user-1",
            submittedLengthUnitPreference: .inches,
            submittedWeightUnitPreference: .pounds,
            submittedDistanceUnitPreference: .miles
        ))

        #expect(screen.presenter.heightUnit == .inches)
        #expect(screen.presenter.weightUnit == .pounds)
        #expect(screen.presenter.distanceUnit == .miles)
    }

    /// Distance gained its own preference after length did, so anyone who onboarded before it
    /// existed has none stored. Falling back to metric would show kilometres to someone who picked
    /// feet and inches; the length choice is the better guess.
    @Test("Test A Missing Distance Preference Follows The Length One")
    func testAMissingDistancePreferenceFollowsTheLengthOne() {
        let imperial = makeScreen(user: UserModel(userId: "user-1", submittedLengthUnitPreference: .inches))
        #expect(imperial.presenter.distanceUnit == .miles)

        let metric = makeScreen(user: UserModel(userId: "user-1", submittedLengthUnitPreference: .centimeters))
        #expect(metric.presenter.distanceUnit == .kilometers)
    }

    /// Nothing stored: the region's measurement system decides, as the rest of the system does.
    @Test("Test No Stored Preferences Follow The Region")
    func testNoStoredPreferencesFollowTheRegion() {
        let screen = makeScreen(user: nil, locale: Locale(identifier: "fr_FR"))

        #expect(screen.presenter.weightUnit == .kilograms)
        #expect(screen.presenter.heightUnit == .centimeters)
        #expect(screen.presenter.distanceUnit == .kilometers)

        let american = makeScreen(user: nil, locale: Locale(identifier: "en_US"))

        #expect(american.presenter.weightUnit == .pounds)
        #expect(american.presenter.heightUnit == .inches)
        #expect(american.presenter.distanceUnit == .miles)
    }

    /// All three are written together on every change, so changing one has to carry the other two
    /// as they stand rather than as they were when the screen opened. Otherwise picking pounds
    /// after picking inches would put height back to centimetres.
    @Test("Test Changing One Unit Does Not Reset The Others")
    func testChangingOneUnitDoesNotResetTheOthers() async {
        let screen = makeScreen(user: UserModel(userId: "user-1"))

        screen.presenter.heightUnit = .inches
        screen.presenter.weightUnit = .pounds
        screen.presenter.distanceUnit = .miles
        await TestManagers.eventually { screen.interactor.saved.count == 3 }

        let saved = screen.interactor.saved.last
        #expect(saved?.length == .inches)
        #expect(saved?.weight == .pounds)
        #expect(saved?.distance == .miles)
    }

    /// Switching away and back has to land on exactly the unit it started from — the screen is the
    /// only place these can be corrected, so a choice that does not round-trip is unrecoverable.
    @Test("Test Switching A Unit And Back Restores It")
    func testSwitchingAUnitAndBackRestoresIt() async {
        let screen = makeScreen(user: UserModel(
            userId: "user-1",
            submittedLengthUnitPreference: .centimeters,
            submittedWeightUnitPreference: .kilograms,
            submittedDistanceUnitPreference: .kilometers
        ))

        screen.presenter.weightUnit = .pounds
        screen.presenter.weightUnit = .kilograms
        await TestManagers.eventually { screen.interactor.saved.count == 2 }

        #expect(screen.presenter.weightUnit == .kilograms)
        #expect(screen.interactor.saved.last?.weight == .kilograms)
        #expect(screen.interactor.saved.last?.length == .centimeters)
        #expect(screen.interactor.saved.last?.distance == .kilometers)
    }

    @Test("Test Appearing And Disappearing Are Tracked")
    func testAppearingAndDisappearingAreTracked() {
        let screen = makeScreen(user: nil)

        screen.presenter.onViewAppear()
        screen.presenter.onViewDisappear()

        #expect(screen.interactor.trackedScreenEventNames == ["UnitsView_Appear"])
        #expect(screen.interactor.trackedEventNames == ["UnitsView_Disappear"])
    }
}

// MARK: - Integrations

/// Connecting Strava. Authorising is a round trip out to another app, so the screen's job is to
/// show that something is happening and to say plainly when it did not work.
@MainActor
struct GeneralSettingsIntegrationsTests {

    private final class Interactor: SpyGlobalInteractor, IntegrationsInteractor {
        var stravaAthlete: StravaAthlete?
        var stravaPendingUploadCount = 0
        var stravaBackfillCount = 0
        private(set) var didDisconnect = false
        private(set) var authenticateCount = 0
        private(set) var testUploadCount = 0
        private(set) var refreshCount = 0
        private(set) var backfillQueued = 0
        private(set) var syncCount = 0

        var authenticateError: Error?
        var disconnectError: Error?
        var testUploadError: Error?

        func stravaAuthenticate() async throws {
            authenticateCount += 1
            if let authenticateError { throw authenticateError }
            stravaAthlete = StravaAthlete(id: 1, firstname: "Alex", lastname: "Runner", profile: nil)
        }

        func stravaDisconnect() async throws {
            if let disconnectError { throw disconnectError }
            didDisconnect = true
            stravaAthlete = nil
        }

        func stravaRefreshConnection() async { refreshCount += 1 }

        func stravaQueueBackfill() -> Int {
            backfillQueued = stravaBackfillCount
            stravaBackfillCount = 0
            return backfillQueued
        }

        func stravaSyncPendingUploads() async { syncCount += 1 }

        func stravaTestUpload() async throws {
            testUploadCount += 1
            if let testUploadError { throw testUploadError }
        }
    }

    /// `IntegrationsRouter` restates `showSimpleAlert` as a requirement, so it dispatches through
    /// the protocol and a double does see it. Every outcome this screen reports goes through it.
    private final class Router: IntegrationsRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var alerts: [String] = []
        private(set) var dialogs: [String] = []

        func showSimpleAlert(title: String, subtitle: String?) {
            alerts.append(title)
        }

        func showConfirmationDialog(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) {
            dialogs.append(title)
        }
    }

    private struct Screen {
        let presenter: IntegrationsPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen() -> Screen {
        let interactor = Interactor()
        let router = Router()
        return Screen(
            presenter: IntegrationsPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    @Test("Test Connecting Strava Reports The Connection")
    func testConnectingStravaReportsTheConnection() async {
        let screen = makeScreen()

        screen.presenter.onStravaConnectPressed()
        await TestManagers.eventually { !screen.presenter.isConnectingStrava }

        #expect(screen.interactor.authenticateCount == 1)
        #expect(screen.presenter.stravaIsConnected)
        #expect(screen.presenter.stravaSubtitle == "Connected as Alex Runner")
        #expect(screen.router.alerts.isEmpty)
    }

    /// Workouts already logged are the next question once connected — and only asked when there are some.
    @Test("Test Connecting Offers To Upload Past Workouts When There Are Some")
    func testConnectingOffersToUploadPastWorkoutsWhenThereAreSome() async {
        let none = makeScreen()
        none.presenter.onStravaConnectPressed()
        await TestManagers.eventually { !none.presenter.isConnectingStrava }
        #expect(none.router.dialogs.isEmpty)

        let some = makeScreen()
        some.interactor.stravaBackfillCount = 12
        some.presenter.onStravaConnectPressed()
        await TestManagers.eventually { !some.presenter.isConnectingStrava }
        #expect(some.router.dialogs == ["Upload 12 past workouts to Strava?"])
    }

    @Test("Test Uploading Past Workouts Queues Them And Starts Sending")
    func testUploadingPastWorkoutsQueuesThemAndStartsSending() async {
        let screen = makeScreen()
        screen.interactor.stravaBackfillCount = 3

        screen.presenter.onStravaBackfillPressed()

        #expect(screen.interactor.backfillQueued == 3)
        #expect(screen.interactor.shownToasts.map(\.style) == [.success])
        #expect(await TestManagers.eventually { screen.interactor.syncCount == 1 })
    }

    @Test("Test Pending Uploads Are Counted")
    func testPendingUploadsAreCounted() {
        let screen = makeScreen()
        #expect(screen.presenter.pendingUploadsText == nil)

        screen.interactor.stravaPendingUploadCount = 2

        #expect(screen.presenter.pendingUploadsText == "2 workouts waiting to upload")
    }

    /// The connection can change elsewhere — another phone, or strava.com — so the screen asks.
    @Test("Test Appearing Refreshes The Connection")
    func testAppearingRefreshesTheConnection() async {
        let screen = makeScreen()

        screen.presenter.onViewAppear()

        #expect(await TestManagers.eventually { screen.interactor.refreshCount == 1 })
    }

    /// Refusing the authorisation, or losing the network partway through it, has to say so. The
    /// spinner stopping on its own would read as a connection that worked.
    @Test("Test A Failed Connection Is Reported And Leaves Strava Disconnected")
    func testAFailedConnectionIsReportedAndLeavesStravaDisconnected() async {
        let screen = makeScreen()
        screen.interactor.authenticateError = URLError(.userAuthenticationRequired)

        screen.presenter.onStravaConnectPressed()
        await TestManagers.eventually { !screen.router.alerts.isEmpty }

        // Was "Connection Failed" with the raw error as its message; now fixed copy.
        #expect(screen.router.alerts == ["Unable to Connect Strava"])
        #expect(!screen.presenter.stravaIsConnected)
        #expect(!screen.presenter.isConnectingStrava)
    }

    /// Closing Strava's sign-in page is not a failure, so it says nothing.
    @Test("Test Cancelling The Strava Sign In Says Nothing")
    func testCancellingTheStravaSignInSaysNothing() async {
        let screen = makeScreen()
        screen.interactor.authenticateError = ASWebAuthenticationSessionError(.canceledLogin)

        screen.presenter.onStravaConnectPressed()
        #expect(await TestManagers.eventually { !screen.presenter.isConnectingStrava })

        #expect(screen.router.alerts.isEmpty)
        #expect(!screen.presenter.stravaIsConnected)
    }

    /// Disconnect asks first, and once confirmed the row follows.
    @Test("Test Disconnecting Strava Asks First Then Drops The Connection")
    func testDisconnectingStravaAsksFirstThenDropsTheConnection() async {
        let screen = makeScreen()
        screen.interactor.stravaAthlete = StravaAthlete(id: 1, firstname: nil, lastname: nil, profile: nil)
        #expect(screen.presenter.stravaSubtitle == "Connected")

        screen.presenter.onStravaDisconnectPressed()
        #expect(screen.router.dialogs == ["Disconnect Strava?"])
        #expect(!screen.interactor.didDisconnect)

        screen.presenter.onStravaDisconnectConfirmed()

        #expect(await TestManagers.eventually { screen.interactor.didDisconnect })
        #expect(!screen.presenter.stravaIsConnected)
    }

    /// Disconnecting is a server call now; failing it must not claim the account is disconnected.
    @Test("Test A Failed Disconnect Is Reported And Stays Connected")
    func testAFailedDisconnectIsReportedAndStaysConnected() async {
        let screen = makeScreen()
        screen.interactor.stravaAthlete = StravaAthlete(id: 1, firstname: nil, lastname: nil, profile: nil)
        screen.interactor.disconnectError = URLError(.notConnectedToInternet)

        screen.presenter.onStravaDisconnectConfirmed()

        #expect(await TestManagers.eventually { screen.router.alerts == ["Unable to Disconnect Strava"] })
        #expect(screen.presenter.stravaIsConnected)
        #expect(!screen.presenter.isDisconnectingStrava)
    }

    /// The test upload exists so the user can prove the connection works. Both outcomes have to be
    /// stated — a silent success is indistinguishable from nothing happening.
    @Test("Test Both Test Upload Outcomes Are Reported")
    func testBothTestUploadOutcomesAreReported() async {
        let screen = makeScreen()

        screen.presenter.onStravaTestUploadPressed()
        await TestManagers.eventually { !screen.interactor.shownToasts.isEmpty }
        let toastStyles = screen.interactor.shownToasts.map { $0.style }
        #expect(toastStyles == [.success])
        #expect(screen.router.alerts.isEmpty)
        #expect(!screen.presenter.isTestingStravaUpload)

        let failing = makeScreen()
        failing.interactor.testUploadError = URLError(.badServerResponse)
        failing.presenter.onStravaTestUploadPressed()
        await TestManagers.eventually { !failing.router.alerts.isEmpty }
        #expect(failing.router.alerts == ["Upload Failed"])
        #expect(!failing.presenter.isTestingStravaUpload)
    }

    @Test("Test Appearing And Disappearing Are Tracked")
    func testAppearingAndDisappearingAreTracked() {
        let screen = makeScreen()

        screen.presenter.onViewAppear()
        screen.presenter.onViewDisappear()

        #expect(screen.interactor.trackedScreenEventNames == ["IntegrationsView_Appear"])
        #expect(screen.interactor.trackedEventNames == ["IntegrationsView_Disappear"])
    }
}

// MARK: - Siri

/// The Siri row. The shortcuts themselves are declared to the system rather than configured here,
/// so the presenter is tracking only.
@MainActor
struct GeneralSettingsSiriTests {

    private final class Interactor: SpyGlobalInteractor, SiriInteractor { }

    private final class Router: SiriRouter { }

    @Test("Test Appearing And Disappearing Are Tracked")
    func testAppearingAndDisappearingAreTracked() {
        let interactor = Interactor()
        let presenter = SiriPresenter(interactor: interactor, router: Router())

        presenter.onViewAppear()
        presenter.onViewDisappear()

        #expect(interactor.trackedScreenEventNames == ["SiriView_Appear"])
        #expect(interactor.trackedEventNames == ["SiriView_Disappear"])
    }
}
