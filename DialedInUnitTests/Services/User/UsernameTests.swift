//
//  UsernameTests.swift
//  DialedInUnitTests
//
//  Handles: the validation rules, availability and claiming through `UserManager`, search routing,
//  the edit screen's presenter, and the Dashboard banner and Account row that lead to it.
//

import Testing
import SwiftUI
@testable import DialedIn

// MARK: - Validation

@MainActor
struct UsernameValidationTests {

    @Test("Test Valid Handles", arguments: ["bob", "bob_lifts", "a.b", "abc123", "_x_", "a1234567890123456789", "priya.runs"])
    func testValidHandles(handle: String) {
        #expect(Username.validate(handle) == .valid)
    }

    @Test("Test Invalid Handles", arguments: [
        ("", Username.Validation.tooShort),
        ("ab", .tooShort),
        ("a12345678901234567890", .tooLong),
        (".bob", .edgeDot),
        ("bob.", .edgeDot),
        ("Bob", .invalidCharacters),
        ("bob lifts", .invalidCharacters),
        ("bob-lifts", .invalidCharacters),
        ("bøb", .invalidCharacters),
        ("@bob", .invalidCharacters)
    ])
    func testInvalidHandles(handle: String, expected: Username.Validation) {
        #expect(Username.validate(handle) == expected)
    }

    @Test("Test Normalising Trims Drops The At Sign And Lowercases")
    func testNormalisingTrimsDropsTheAtSignAndLowercases() {
        #expect(Username.normalised("  @Bob_Lifts ") == "bob_lifts")
        #expect(Username.normalised("ALICE") == "alice")
    }
}

// MARK: - Search routing

@MainActor
struct UsernameSearchRoutingTests {

    @Test("Test An At Query Searches Handles Only")
    func testAnAtQuerySearchesHandlesOnly() {
        let route = Username.searchRoute(for: "@Bob_L")
        #expect(route.name == nil)
        #expect(route.handlePrefix == "bob_l")
    }

    @Test("Test A One Word Query Searches Names And Handles")
    func testAOneWordQuerySearchesNamesAndHandles() {
        let route = Username.searchRoute(for: " Bob ")
        #expect(route.name == "Bob")
        #expect(route.handlePrefix == "bob")
    }

    @Test("Test A Query Outside The Handle Charset Searches Names Only")
    func testAQueryOutsideTheHandleCharsetSearchesNamesOnly() {
        let route = Username.searchRoute(for: "Bob Martinez")
        #expect(route.name == "Bob Martinez")
        #expect(route.handlePrefix == nil)
        #expect(Username.searchRoute(for: "@").handlePrefix == nil)
    }

    /// Records which searches the manager ran.
    private final class SpyQueryService: MockUserQueryService {
        private(set) var nameQueries: [String] = []
        private(set) var handlePrefixes: [String] = []

        override func searchUsers(query: String) async throws -> [UserModel] {
            nameQueries.append(query)
            return UserModel.mocks.filter { $0.firstNameCalculated == query }
        }

        override func searchUsers(usernamePrefix: String) async throws -> [UserModel] {
            handlePrefixes.append(usernamePrefix)
            return try await super.searchUsers(usernamePrefix: usernamePrefix)
        }
    }

    private func manager(_ service: SpyQueryService) -> UserManager {
        UserManager(
            queryService: service,
            userSyncEngine: TestManagers.documentEngine(UserModel?.none, key: "user"),
            followingUsersSyncEngine: TestManagers.collectionEngine([UserModel](), key: "following-users"),
            privateSettingsSyncEngine: TestManagers.documentEngine(PrivateUserSettings?.none, key: "private-user-settings")
        )
    }

    @Test("Test The Manager Routes An At Query To Handles And Merges A Plain One")
    func testTheManagerRoutesAnAtQueryToHandlesAndMergesAPlainOne() async throws {
        let service = SpyQueryService()
        let manager = manager(service)

        let byHandle = try await manager.searchUsersByNameOrHandle(query: "@bob")
        #expect(service.nameQueries.isEmpty)
        #expect(service.handlePrefixes == ["bob"])
        #expect(byHandle.map(\.userId) == ["user2"])

        // "Bob" is found by name and by handle; he appears once.
        let both = try await manager.searchUsersByNameOrHandle(query: "Bob")
        #expect(service.nameQueries == ["Bob"])
        #expect(service.handlePrefixes == ["bob", "bob"])
        #expect(both.map(\.userId) == ["user2"])
    }
}

// MARK: - Availability and claiming

@MainActor
struct UsernameClaimTests {

    /// A reservation read that always says "free", so the reserve write is what finds the clash.
    private final class RacingQueryService: MockUserQueryService {
        override func usernameOwner(_ handle: String) async throws -> String? { nil }
    }

    private struct Fixture {
        let manager: UserManager
        let remote: RecordingRemoteDocumentService<UserModel>
        let service: MockUserQueryService
    }

    private func signedIn(
        _ user: UserModel = UserModel(userId: "me"),
        service: MockUserQueryService = MockUserQueryService()
    ) async throws -> Fixture {
        let remote = RecordingRemoteDocumentService<UserModel>(document: user)
        let manager = UserManager(
            queryService: service,
            userSyncEngine: DocumentSyncEngine<UserModel>(
                remote: remote,
                managerKey: TestManagers.key("user"),
                enableLocalPersistence: false
            ),
            followingUsersSyncEngine: TestManagers.collectionEngine([UserModel](), key: "following-users"),
            privateSettingsSyncEngine: TestManagers.documentEngine(PrivateUserSettings?.none, key: "private-user-settings")
        )
        try await manager.signIn(auth: UserAuthInfo(uid: user.userId), isNewUser: false)
        #expect(await TestManagers.eventually { manager.currentUser != nil })
        return Fixture(manager: manager, remote: remote, service: service)
    }

    private func usernameWrites(_ remote: RecordingRemoteDocumentService<UserModel>) -> [String] {
        remote.updates.compactMap { $0[UserModel.CodingKeys.username.rawValue] as? String }
    }

    @Test("Test Availability")
    func testAvailability() async throws {
        let fixture = try await signedIn(UserModel(userId: "user2").withUsername("bob_lifts"))

        #expect(try await fixture.manager.isUsernameAvailable("fresh_handle"))
        #expect(try await !fixture.manager.isUsernameAvailable("alice"))
        // Your own handle is not "taken" from you.
        #expect(try await fixture.manager.isUsernameAvailable("@Bob_Lifts"))
        #expect(try await !fixture.manager.isUsernameAvailable("no"))
    }

    @Test("Test Claiming Reserves Then Writes The Profile")
    func testClaimingReservesThenWritesTheProfile() async throws {
        let fixture = try await signedIn()

        try await fixture.manager.claimUsername("@New.Handle")

        #expect(try await fixture.service.usernameOwner("new.handle") == "me")
        #expect(usernameWrites(fixture.remote) == ["new.handle"])
    }

    @Test("Test A Taken Handle Is Refused Without Writing")
    func testATakenHandleIsRefusedWithoutWriting() async throws {
        let fixture = try await signedIn()

        await #expect(throws: UsernameError.taken) {
            try await fixture.manager.claimUsername("bob_lifts")
        }
        #expect(try await fixture.service.usernameOwner("bob_lifts") == "user2")
        #expect(usernameWrites(fixture.remote).isEmpty)
    }

    @Test("Test A Reservation That Fails To Write Surfaces As Taken")
    func testAReservationThatFailsToWriteSurfacesAsTaken() async throws {
        let fixture = try await signedIn(service: RacingQueryService())

        await #expect(throws: UsernameError.taken) {
            try await fixture.manager.claimUsername("alice")
        }
        #expect(usernameWrites(fixture.remote).isEmpty)
    }

    @Test("Test An Invalid Handle Is Refused")
    func testAnInvalidHandleIsRefused() async throws {
        let fixture = try await signedIn()

        await #expect(throws: UsernameError.invalid) {
            try await fixture.manager.claimUsername(".bad")
        }
        #expect(usernameWrites(fixture.remote).isEmpty)
    }
}

// MARK: - Edit screen

@MainActor
struct EditUsernamePresenterTests {

    private final class Interactor: SpyGlobalInteractor, EditUsernameInteractor {
        var currentUser: UserModel?
        var taken: Set<String> = ["bob_lifts"]
        var availabilityError: Error?
        var claimError: Error?
        private(set) var checked: [String] = []
        private(set) var claimed: [String] = []

        func isUsernameAvailable(_ handle: String) async throws -> Bool {
            checked.append(handle)
            if let availabilityError { throw availabilityError }
            return !taken.contains(handle)
        }

        func claimUsername(_ handle: String) async throws {
            if let claimError { throw claimError }
            claimed.append(handle)
        }
    }

    private final class Router: EditUsernameRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var alertTitles: [String] = []
        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) { alertTitles.append(title) }
        func showSimpleAlert(title: String, subtitle: String?) { alertTitles.append(title) }
    }

    private struct Screen {
        let presenter: EditUsernamePresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen(username: String? = nil) -> Screen {
        let interactor = Interactor()
        interactor.currentUser = UserModel(userId: "me").withUsername(username)
        let router = Router()
        return Screen(
            presenter: EditUsernamePresenter(interactor: interactor, router: router, debounce: .zero),
            interactor: interactor,
            router: router
        )
    }

    private func type(_ text: String, into presenter: EditUsernamePresenter) {
        presenter.text = text
        presenter.onTextChanged()
    }

    /// Offline the availability read answers from the cache, which can call a taken handle free,
    /// so nothing is checked and Save stays off.
    @Test("Test Offline A Handle Is Not Checked")
    func testOfflineAHandleIsNotChecked() {
        let screen = makeScreen()
        screen.interactor.isOffline = true

        type("new_handle", into: screen.presenter)

        #expect(screen.presenter.status == .failed)
        #expect(screen.interactor.checked.isEmpty)
        #expect(!screen.presenter.canSave)
    }

    /// The signal went after the check: Save says so rather than waiting on a reservation write.
    @Test("Test Offline Save Says You're Offline And Claims Nothing")
    func testOfflineSaveSaysYoureOfflineAndClaimsNothing() async {
        let screen = makeScreen()
        type("new_handle", into: screen.presenter)
        #expect(await TestManagers.eventually { screen.presenter.canSave })
        screen.interactor.isOffline = true

        await screen.presenter.onSavePressed()

        #expect(screen.router.alertTitles == [OfflineError.title])
        #expect(screen.interactor.claimed.isEmpty)
        #expect(!screen.presenter.isSaving)
    }

    @Test("Test It Starts On The Current Handle")
    func testItStartsOnTheCurrentHandle() {
        let presenter = makeScreen(username: "andrew").presenter
        #expect(presenter.text == "andrew")
        #expect(presenter.status == .current)
        #expect(!presenter.canSave)
    }

    @Test("Test Typing Lowercases And Reports Available")
    func testTypingLowercasesAndReportsAvailable() async {
        let screen = makeScreen()
        let (presenter, interactor) = (screen.presenter, screen.interactor)

        type("New_Handle", into: presenter)

        #expect(presenter.text == "new_handle")
        #expect(await TestManagers.eventually { presenter.status == .available })
        #expect(interactor.checked == ["new_handle"])
        #expect(presenter.canSave)
    }

    @Test("Test A Taken Handle Cannot Be Saved")
    func testATakenHandleCannotBeSaved() async {
        let presenter = makeScreen().presenter

        type("bob_lifts", into: presenter)

        #expect(await TestManagers.eventually { presenter.status == .taken })
        #expect(!presenter.canSave)
    }

    @Test("Test An Invalid Handle Is Flagged Without A Check")
    func testAnInvalidHandleIsFlaggedWithoutACheck() async {
        let screen = makeScreen()
        let (presenter, interactor) = (screen.presenter, screen.interactor)

        type("ab", into: presenter)
        #expect(presenter.status == .invalid(Username.Validation.tooShort.message ?? ""))
        type("bob.", into: presenter)
        #expect(presenter.status == .invalid(Username.Validation.edgeDot.message ?? ""))

        try? await Task.sleep(for: .milliseconds(50))
        #expect(interactor.checked.isEmpty)
        #expect(!presenter.canSave)
    }

    @Test("Test A Failed Check Is Not Reported As Taken")
    func testAFailedCheckIsNotReportedAsTaken() async {
        let screen = makeScreen()
        let (presenter, interactor) = (screen.presenter, screen.interactor)
        interactor.availabilityError = URLError(.notConnectedToInternet)

        type("fresh", into: presenter)

        #expect(await TestManagers.eventually { presenter.status == .failed })
    }

    @Test("Test Save Claims The Handle")
    func testSaveClaimsTheHandle() async {
        let screen = makeScreen()
        let (presenter, interactor) = (screen.presenter, screen.interactor)
        type("fresh", into: presenter)
        #expect(await TestManagers.eventually { presenter.canSave })

        await presenter.onSavePressed()

        #expect(interactor.claimed == ["fresh"])
        #expect(interactor.trackedEventNames.contains("EditUsernameView_Save_Success"))
    }

    @Test("Test Losing The Race On Save Shows Taken")
    func testLosingTheRaceOnSaveShowsTaken() async {
        let screen = makeScreen()
        let (presenter, interactor, router) = (screen.presenter, screen.interactor, screen.router)
        type("fresh", into: presenter)
        #expect(await TestManagers.eventually { presenter.canSave })
        interactor.claimError = UsernameError.taken

        await presenter.onSavePressed()

        #expect(presenter.status == .taken)
        #expect(router.alertTitles.isEmpty)
    }
}

// MARK: - Ways in

@MainActor
struct UsernameEntryPointTests {

    @Test("Test The Dashboard Asks Only A Signed In User Without A Handle")
    func testTheDashboardAsksOnlyASignedInUserWithoutAHandle() {
        let interactor = DashboardFeedPresenterTests.Interactor()
        let router = DashboardFeedPresenterTests.Router()
        let presenter = DashboardPresenter(interactor: interactor, router: router)

        interactor.currentUser = UserModel(userId: "me")
        #expect(presenter.needsUsername)

        presenter.onPickUsernamePressed()
        #expect(router.shown == ["editUsername"])

        interactor.currentUser = UserModel(userId: "me").withUsername("andrew")
        #expect(!presenter.needsUsername)
        interactor.currentUser = nil
        #expect(!presenter.needsUsername)
    }

    @Test("Test The Mock Roster Has Handles And Reservations For Them")
    func testTheMockRosterHasHandlesAndReservationsForThem() async throws {
        let service = MockUserQueryService()
        #expect(UserModel.mockExisting.username == "alice.cooper")
        for user in UserModel.mocks {
            guard let handle = user.username else { continue }
            #expect(Username.isValid(handle))
            #expect(try await service.usernameOwner(handle) == user.userId)
        }
        #expect(UserModel.mocks.contains { $0.username == nil })
    }
}
