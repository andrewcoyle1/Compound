//
//  GeneralSettingsPresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
@testable import DialedIn

// MARK: - Shortcuts

/// The quick actions on the Search tab, in the order the user arranged them.
///
/// This is the one settings screen here whose value is an ordered list rather than a set of
/// switches, so the things that can go wrong are list things: a removal taking a neighbour with it,
/// a reorder losing an entry, an add producing a duplicate.
@MainActor
struct GeneralSettingsShortcutsTests {

    private final class Interactor: SpyGlobalInteractor, ShortcutsInteractor {
        var shortcutSettings = ShortcutSettings(authorId: "user-1")
        private(set) var savedSettings: [ShortcutSettings] = []

        func saveShortcutSettings(_ settings: ShortcutSettings) async throws {
            savedSettings.append(settings)
            shortcutSettings = settings
        }
    }

    private final class Router: ShortcutsRouter {
        let router: AnyRouter = TestRouting.anyRouter
    }

    private struct Screen {
        let presenter: ShortcutsPresenter
        let interactor: Interactor
    }

    private func makeScreen(actions: [QuickAction]? = nil) -> Screen {
        let interactor = Interactor()
        if let actions {
            interactor.shortcutSettings.setQuickActions(actions)
        }
        return Screen(
            presenter: ShortcutsPresenter(interactor: interactor, router: Router()),
            interactor: interactor
        )
    }

    /// Someone who has never opened this screen sees the default four. Anything else would silently
    /// rearrange a row they are used to.
    @Test("Test An Untouched List Shows The Defaults")
    func testAnUntouchedListShowsTheDefaults() {
        let screen = makeScreen()

        #expect(screen.presenter.quickActions == QuickAction.defaultActions)
        #expect(screen.presenter.isShowingDefaults)
    }

    /// The "available" list is everything not already on the grid, so an action cannot be added
    /// twice from it.
    @Test("Test Available Actions Are The Ones Not Already Shown")
    func testAvailableActionsAreTheOnesNotAlreadyShown() {
        let screen = makeScreen()

        let available = screen.presenter.availableActions

        #expect(available.allSatisfy { !QuickAction.defaultActions.contains($0) })
        #expect(available.count == QuickAction.allCases.count - QuickAction.defaultActions.count)
    }

    /// Adding appends to the end of the arranged order and keeps everything already there.
    @Test("Test Adding An Action Keeps The Existing Ones")
    func testAddingAnActionKeepsTheExistingOnes() async {
        let screen = makeScreen()

        screen.presenter.onAddPressed(.browseRecipes)
        await TestManagers.eventually { !screen.interactor.savedSettings.isEmpty }

        #expect(screen.presenter.quickActions == QuickAction.defaultActions + [.browseRecipes])
        #expect(screen.interactor.savedSettings.last?.quickActions == QuickAction.defaultActions + [.browseRecipes])
    }

    /// Two taps on the same row — or a stale list — must not leave the same tile on the grid twice.
    @Test("Test Adding An Action Twice Does Not Duplicate It")
    func testAddingAnActionTwiceDoesNotDuplicateIt() async {
        let screen = makeScreen()

        screen.presenter.onAddPressed(.browseRecipes)
        screen.presenter.onAddPressed(.browseRecipes)
        await TestManagers.eventually { !screen.interactor.savedSettings.isEmpty }

        #expect(screen.presenter.quickActions.filter { $0 == .browseRecipes }.count == 1)
        #expect(screen.interactor.savedSettings.count == 1)
    }

    /// Swiping one row away must take exactly that one. This is the list version of one setting's
    /// save clobbering another.
    @Test("Test Removing One Action Keeps The Others In Order")
    func testRemovingOneActionKeepsTheOthersInOrder() async {
        let screen = makeScreen()

        screen.presenter.onRemove(at: IndexSet(integer: 1))
        await TestManagers.eventually { !screen.interactor.savedSettings.isEmpty }

        let expected = [QuickAction.startWorkout, .logWeight, .logMeasurement]
        #expect(screen.presenter.quickActions == expected)
        #expect(screen.interactor.savedSettings.last?.quickActions == expected)
    }

    /// Dragging a tile up the list is a reorder, not a copy or a delete: the same actions come out,
    /// in the new order.
    @Test("Test Reordering Keeps Every Action")
    func testReorderingKeepsEveryAction() async {
        let screen = makeScreen()

        screen.presenter.onMove(from: IndexSet(integer: 3), to: 0)
        await TestManagers.eventually { !screen.interactor.savedSettings.isEmpty }

        #expect(screen.presenter.quickActions == [.logMeasurement, .startWorkout, .logMeal, .logWeight])
        #expect(Set(screen.presenter.quickActions) == Set(QuickAction.defaultActions))
    }

    /// Whatever someone has done to the list, Restore Defaults has to be a way back to a working
    /// grid — including from an empty one.
    @Test("Test Restoring Defaults Recovers An Emptied Grid")
    func testRestoringDefaultsRecoversAnEmptiedGrid() async {
        let screen = makeScreen(actions: [])
        #expect(screen.presenter.quickActions.isEmpty)

        screen.presenter.onRestoreDefaultsPressed()
        await TestManagers.eventually { !screen.interactor.savedSettings.isEmpty }

        #expect(screen.presenter.quickActions == QuickAction.defaultActions)
        #expect(screen.interactor.savedSettings.last?.quickActions == QuickAction.defaultActions)
    }

    /// Unknown ids are dropped rather than crashing or leaving a gap, so a grid saved by a newer
    /// build still opens on an older one.
    @Test("Test An Unrecognised Saved Action Is Dropped")
    func testAnUnrecognisedSavedActionIsDropped() {
        let screen = makeScreen()
        screen.interactor.shortcutSettings.quickActionIds = ["start_workout", "not_a_real_action"]
        let presenter = ShortcutsPresenter(interactor: screen.interactor, router: Router())

        #expect(presenter.quickActions == [.startWorkout])
    }

    @Test("Test Each Edit Is Tracked")
    func testEachEditIsTracked() async {
        let screen = makeScreen()

        screen.presenter.onAddPressed(.browseRecipes)
        screen.presenter.onMove(from: IndexSet(integer: 0), to: 2)
        screen.presenter.onRemove(at: IndexSet(integer: 0))
        screen.presenter.onRestoreDefaultsPressed()

        #expect(screen.interactor.trackedEventNames == [
            "ShortcutsView_Action_Added",
            "ShortcutsView_Actions_Reordered",
            "ShortcutsView_Actions_Removed",
            "ShortcutsView_Defaults_Restored"
        ])
    }

    @Test("Test Appearing And Disappearing Are Tracked")
    func testAppearingAndDisappearingAreTracked() {
        let screen = makeScreen()

        screen.presenter.onViewAppear()
        screen.presenter.onViewDisappear()

        #expect(screen.interactor.trackedScreenEventNames == ["ShortcutsView_Appear"])
        #expect(screen.interactor.trackedEventNames == ["ShortcutsView_Disappear"])
    }
}

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

    private func makeScreen(user: UserModel?) -> Screen {
        let interactor = Interactor()
        interactor.currentUser = user
        return Screen(
            presenter: UnitsPresenter(interactor: interactor, router: Router()),
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

    @Test("Test No Stored Preferences Fall Back To Metric")
    func testNoStoredPreferencesFallBackToMetric() {
        let screen = makeScreen(user: nil)

        #expect(screen.presenter.weightUnit == .kilograms)
        #expect(screen.presenter.heightUnit == .centimeters)
        #expect(screen.presenter.distanceUnit == .kilometers)
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
        var stravaIsConnected = false
        private(set) var didDisconnect = false
        private(set) var authenticateCount = 0
        private(set) var testUploadCount = 0

        var authenticateError: Error?
        var testUploadError: Error?

        func stravaAuthenticate() async throws {
            authenticateCount += 1
            if let authenticateError { throw authenticateError }
            stravaIsConnected = true
        }

        func stravaDisconnect() {
            didDisconnect = true
            stravaIsConnected = false
        }

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

        func showSimpleAlert(title: String, subtitle: String?) {
            alerts.append(title)
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
        #expect(screen.router.alerts.isEmpty)
    }

    /// Refusing the authorisation, or losing the network partway through it, has to say so. The
    /// spinner stopping on its own would read as a connection that worked.
    @Test("Test A Failed Connection Is Reported And Leaves Strava Disconnected")
    func testAFailedConnectionIsReportedAndLeavesStravaDisconnected() async {
        let screen = makeScreen()
        screen.interactor.authenticateError = URLError(.userAuthenticationRequired)

        screen.presenter.onStravaConnectPressed()
        await TestManagers.eventually { !screen.router.alerts.isEmpty }

        #expect(screen.router.alerts == ["Connection Failed"])
        #expect(!screen.presenter.stravaIsConnected)
        #expect(!screen.presenter.isConnectingStrava)
    }

    @Test("Test Disconnecting Strava Drops The Connection")
    func testDisconnectingStravaDropsTheConnection() {
        let screen = makeScreen()
        screen.interactor.stravaIsConnected = true

        screen.presenter.onStravaDisconnectPressed()

        #expect(screen.interactor.didDisconnect)
        #expect(!screen.presenter.stravaIsConnected)
    }

    /// The test upload exists so the user can prove the connection works. Both outcomes have to be
    /// stated — a silent success is indistinguishable from nothing happening.
    @Test("Test Both Test Upload Outcomes Are Reported")
    func testBothTestUploadOutcomesAreReported() async {
        let screen = makeScreen()

        screen.presenter.onStravaTestUploadPressed()
        await TestManagers.eventually { !screen.router.alerts.isEmpty }
        #expect(screen.router.alerts == ["Upload Successful"])
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
