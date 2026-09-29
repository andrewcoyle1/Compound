//
//  InviteTests.swift
//  DialedInUnitTests
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

/// The code an invite is keyed by, and the one-per-user invite built from it.
@MainActor
struct InviteCodeTests {

    @Test("Test A Code Is Eight Characters From The Unambiguous Alphabet")
    func testACodeIsEightCharactersFromTheUnambiguousAlphabet() {
        for _ in 0..<200 {
            let code = InviteCode.random()
            #expect(code.count == 8)
            #expect(code.allSatisfy { InviteCode.alphabet.contains($0) })
        }
        #expect(!InviteCode.alphabet.contains { "01ILO".contains($0) })
    }

    @Test("Test A Typed Code Is Normalised And A Wrong One Refused")
    func testATypedCodeIsNormalisedAndAWrongOneRefused() {
        #expect(InviteCode.normalised("push 2345") == "PUSH2345")
        #expect(InviteCode.normalised("PUSH-2345") == "PUSH2345")
        #expect(InviteCode.normalised("PUSH234") == nil)
        #expect(InviteCode.normalised("PUSH2340") == nil)
        #expect(InviteCode.normalised("") == nil)
    }

    /// A code someone else holds is redrawn rather than overwritten.
    @Test("Test A Colliding Code Is Redrawn")
    func testACollidingCodeIsRedrawn() async throws {
        let service = MockInviteService(invites: [InviteModel(code: "AAAAAAAA", inviterId: "someone")])
        let manager = InviteManager(service: service)
        var draws = ["AAAAAAAA", "BBBBBBBB"]

        let invite = try await manager.invite(for: "me") { draws.removeFirst() }

        #expect(invite.code == "BBBBBBBB")
        #expect(invite.inviterId == "me")
        #expect(service.invites["AAAAAAAA"]?.inviterId == "someone")
        #expect(service.invites["BBBBBBBB"]?.inviterId == "me")
    }

    /// One invite per user: sharing again reuses it.
    @Test("Test An Existing Invite Is Reused")
    func testAnExistingInviteIsReused() async throws {
        let service = MockInviteService(invites: [])
        let manager = InviteManager(service: service)

        let first = try await manager.invite(for: "me")
        let second = try await manager.invite(for: "me") { Issue.record("should not draw again"); return "CCCCCCCC" }

        #expect(first == second)
        #expect(service.invites.count == 1)
        #expect(first.link.absoluteString == "compound://join/\(first.code)")
    }

    @Test("Test Every Draw Colliding Gives Up")
    func testEveryDrawCollidingGivesUp() async {
        let manager = InviteManager(service: MockInviteService(invites: [InviteModel(code: "AAAAAAAA", inviterId: "someone")]))

        await #expect(throws: AppError.self) {
            _ = try await manager.invite(for: "me") { "AAAAAAAA" }
        }
    }

    /// A malformed code never reaches the Cloud Function.
    @Test("Test Accepting A Malformed Code Fails Before The Service")
    func testAcceptingAMalformedCodeFailsBeforeTheService() async throws {
        let manager = InviteManager(service: MockInviteService())

        await #expect(throws: InviteError.invalidCode) { _ = try await manager.acceptInvite(code: "nope") }
        let acceptance = try await manager.acceptInvite(code: "push 2345")
        #expect(acceptance.inviterId == "user1")
    }

    /// The mock mirrors the function's refusals, so the mock scenario behaves like the real one.
    @Test("Test The Mock Refuses Own, Unknown And Used Up Invites")
    func testTheMockRefusesOwnUnknownAndUsedUpInvites() async throws {
        let service = MockInviteService(
            invites: [
                InviteModel(code: "MINE2345", inviterId: "me"),
                InviteModel(code: "FULL2345", inviterId: "user1", uses: 50)
            ],
            callerId: "me"
        )

        await #expect(throws: InviteError.ownInvite) { _ = try await service.acceptInvite(code: "MINE2345") }
        await #expect(throws: InviteError.exhausted) { _ = try await service.acceptInvite(code: "FULL2345") }
        await #expect(throws: InviteError.notFound) { _ = try await service.acceptInvite(code: "GONE2345") }
    }
}

/// `compound://join/<code>` through `DeepLink` and the tab bar.
@MainActor
struct InviteDeepLinkTests {

    @Test("Test A Join Link Parses To Its Normalised Code")
    func testAJoinLinkParsesToItsNormalisedCode() throws {
        #expect(DeepLink(url: try #require(URL(string: "compound://join/PUSH2345"))) == .join(code: "PUSH2345"))
        #expect(DeepLink(url: try #require(URL(string: "compound://join/push2345"))) == .join(code: "PUSH2345"))
        #expect(DeepLink(url: try #require(URL(string: "compound://JOIN/PUSH2345/"))) == .join(code: "PUSH2345"))
        #expect(DeepLink(pushUserInfo: ["deep_link": "compound://join/PUSH2345"]) == .join(code: "PUSH2345"))
    }

    @Test("Test A Join Link Without A Valid Code Is Refused")
    func testAJoinLinkWithoutAValidCodeIsRefused() throws {
        #expect(DeepLink(url: try #require(URL(string: "compound://join"))) == nil)
        #expect(DeepLink(url: try #require(URL(string: "compound://join/SHORT"))) == nil)
        #expect(DeepLink(url: try #require(URL(string: "compound://join/PUSH2340"))) == nil)
    }

    /// The tab bar lands on the Dashboard and asks it to accept.
    @Test("Test A Join Link Selects The Dashboard And Asks It To Accept")
    func testAJoinLinkSelectsTheDashboardAndAsksItToAccept() async throws {
        let interactor = TabBarInteractorDouble()
        let presenter = TabBarPresenter(interactor: interactor, router: TabBarRouterDouble())
        presenter.selectedTabTitle = "Training"
        var received: String?
        let observer = NotificationCenter.default.addObserver(forName: Constants.acceptInvite, object: nil, queue: .main) { note in
            received = note.userInfo?["code"] as? String
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        presenter.onOpenURL(try #require(URL(string: "compound://join/push2345")))

        #expect(await TestManagers.eventually { received == "PUSH2345" })
        #expect(presenter.selectedTabTitle == "Dashboard")
        #expect(interactor.trackedEventNames == ["TabBarView_DeepLink_Join"])
    }

    private final class TabBarInteractorDouble: SpyGlobalInteractor, TabBarInteractor {
        func consumePendingDeepLink() -> DeepLink? { nil }
        var activeSession: WorkoutSessionModel?
        var draftMeal: MealLogModel?
        var activityNotifications: [ActivityNotificationModel] = []
        var incomingFollowRequests: [FollowRequestModel] = []
    }

    private final class TabBarRouterDouble: TabBarRouter {
        let router: AnyRouter = TestRouting.anyRouter
        func showWorkoutTrackerView() { }
        func showAlert(error: Error) { }
        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) { }
        func showSimpleAlert(title: String, subtitle: String?) { }
    }
}

/// Accepting, shared by the Dashboard (links) and Search (typed codes).
@MainActor
struct InviteAcceptFlowTests {

    final class Interactor: SpyGlobalInteractor, InviteAcceptInteractor {
        var result: Result<(inviter: UserModel, acceptance: InviteAcceptance), Error> = .failure(InviteError.notFound)
        private(set) var codes: [String] = []

        func acceptInvite(code: String) async throws -> (inviter: UserModel, acceptance: InviteAcceptance) {
            codes.append(code)
            return try result.get()
        }
    }

    final class Router: InviteAcceptRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var profileUserIds: [String] = []
        private(set) var alerts: [String] = []

        func showSocialProfileView(delegate: SocialProfileDelegate) { profileUserIds.append(delegate.user.userId) }
        func showSimpleAlert(title: String, subtitle: String?) { alerts.append("\(title): \(subtitle ?? "")") }
        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) { alerts.append(title) }
    }

    private func inviter() -> UserModel {
        UserModel(userId: "alex", firstName: "Alex")
    }

    @Test("Test Accepting Opens The Inviter With A Following Toast")
    func testAcceptingOpensTheInviterWithAFollowingToast() async {
        let interactor = Interactor()
        let router = Router()
        interactor.result = .success((inviter(), InviteAcceptance(inviterId: "alex", youFollow: .following, theyFollow: .following)))

        await InviteAcceptFlow(interactor: interactor, router: router).accept(code: "PUSH2345")

        #expect(interactor.codes == ["PUSH2345"])
        #expect(router.profileUserIds == ["alex"])
        #expect(router.alerts.isEmpty)
        #expect(interactor.shownToasts.map(\.message) == ["You're now following each other"])
        #expect(interactor.trackedEventNames == ["Invite_Accept_Start", "Invite_Accept_Success"])
    }

    /// A private profile on either side gets a request, and the toast says which.
    @Test("Test A Private Profile Says A Request Is Waiting")
    func testAPrivateProfileSaysARequestIsWaiting() async {
        let interactor = Interactor()
        interactor.result = .success((inviter(), InviteAcceptance(inviterId: "alex", youFollow: .requested, theyFollow: .following)))

        await InviteAcceptFlow(interactor: interactor, router: Router()).accept(code: "PUSH2345")

        #expect(interactor.shownToasts.map(\.message) == ["Alex is following you. Your follow request is waiting."])
    }

    @Test("Test Offline Accept Says You're Offline And Calls Nothing")
    func testOfflineAcceptSaysYoureOfflineAndCallsNothing() async {
        let interactor = Interactor()
        interactor.isOffline = true
        let router = Router()

        await InviteAcceptFlow(interactor: interactor, router: router).accept(code: "PUSH2345")

        #expect(interactor.codes.isEmpty)
        #expect(router.alerts == ["\(OfflineError.title): \(OfflineError.message)"])
        #expect(router.profileUserIds.isEmpty)
    }

    @Test("Test A Refused Invite Explains Why And Opens Nothing")
    func testARefusedInviteExplainsWhyAndOpensNothing() async {
        let interactor = Interactor()
        let router = Router()
        interactor.result = .failure(InviteError.ownInvite)

        await InviteAcceptFlow(interactor: interactor, router: router).accept(code: "PUSH2345")

        #expect(router.profileUserIds.isEmpty)
        #expect(router.alerts == ["Couldn't accept invite: That's your own invite. Send it to a friend."])
        #expect(interactor.shownToasts.isEmpty)
    }

    /// The Dashboard answers the tab bar's notification with the same flow.
    @Test("Test The Dashboard Accepts A Relayed Invite")
    func testTheDashboardAcceptsARelayedInvite() async {
        let interactor = DashboardFeedPresenterTests.Interactor()
        let router = DashboardFeedPresenterTests.Router()
        let presenter = DashboardPresenter(interactor: interactor, router: router)

        presenter.onAcceptInviteNotificationReceived(Notification(name: Constants.acceptInvite, object: nil, userInfo: ["code": "PUSH2345"]))

        // The double refuses every code, so the Dashboard shows why.
        #expect(await TestManagers.eventually { interactor.trackedEventNames.contains("Invite_Accept_Fail") })
    }
}
