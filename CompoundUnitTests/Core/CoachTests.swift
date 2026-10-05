//
//  CoachTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
import SwiftUI
import FirebaseFunctions
@testable import Compound

/// The AI coach on the app's side: the gate (premium, then consent), the streamed answer, what a
/// refusal does, the saved chats, and the ways into it from other screens. The function itself is
/// tested in `functions/`.
/// One message `CoachTests.Interactor` was asked to send.
struct CoachSentMessage {
    let message: String
    let chatId: String?
    let context: CoachContext?
}

@MainActor
struct CoachTests {

    // MARK: - Doubles

    final class Interactor: SpyGlobalInteractor, CoachInteractor {
        var isPremium = true
        var coachHasConsented = true
        var coachChats: [CoachChat] = []
        var coachRemainingToday: Int?
        var events: [CoachStreamEvent] = [.text("Hello "), .text("there"), .finished(chatId: "c1", messageId: "a1", text: "Hello there", remainingToday: 49)]
        var sendError: Error?
        var consentError: Error?
        private(set) var sent: [CoachSentMessage] = []
        private(set) var consentGiven = 0
        private(set) var consentWithdrawn = 0
        private(set) var deletedChatIds: [String] = []

        func coachChat(id: String) -> CoachChat? { coachChats.first { $0.id == id } }

        func coachGiveConsent() async throws {
            if let consentError { throw consentError }
            consentGiven += 1
            coachHasConsented = true
        }

        func coachWithdrawConsent() async throws {
            consentWithdrawn += 1
            coachHasConsented = false
        }

        func coachDeleteChat(id: String) async throws { deletedChatIds.append(id) }

        func coachSend(message: String, chatId: String?, context: CoachContext?) -> AsyncThrowingStream<CoachStreamEvent, Error> {
            sent.append(CoachSentMessage(message: message, chatId: chatId, context: context))
            let events = events
            let error = sendError
            return AsyncThrowingStream { continuation in
                if let error {
                    continuation.finish(throwing: error)
                    return
                }
                for event in events { continuation.yield(event) }
                continuation.finish()
            }
        }
    }

    final class Router: CoachRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var shown: [String] = []
        private(set) var openedChats: [CoachDelegate] = []
        private(set) var dialogTitles: [String] = []

        func showPaywall(isOnboarding: Bool) { shown.append("paywall") }
        func showCoachChatsView(delegate: CoachChatsDelegate) { shown.append("chats") }
        func showCoachChatView(delegate: CoachDelegate) {
            shown.append("chat")
            openedChats.append(delegate)
        }
        func dismissScreen() { shown.append("dismiss") }
        func showConfirmationDialog(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) { dialogTitles.append(title) }
    }

    private struct Screen {
        let presenter: CoachPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen(context: CoachContext = .today, chatId: String? = nil, configure: (Interactor) -> Void = { _ in }) -> Screen {
        let interactor = Interactor()
        configure(interactor)
        let router = Router()
        let presenter = CoachPresenter(interactor: interactor, router: router, delegate: CoachDelegate(context: context, chatId: chatId))
        return Screen(presenter: presenter, interactor: interactor, router: router)
    }

    // MARK: - The gate

    /// Premium first, then consent: nothing is sent to the provider before both.
    @Test("Test The Gate Is Premium Then Consent Then Chat")
    func testGate() {
        let notPremium = makeScreen { $0.isPremium = false; $0.coachHasConsented = false }
        notPremium.presenter.onViewAppear()
        #expect(notPremium.presenter.gate == .premium)
        notPremium.presenter.onSeePlansPressed()
        #expect(notPremium.router.shown == ["paywall"])

        let noConsent = makeScreen { $0.coachHasConsented = false }
        noConsent.presenter.onViewAppear()
        #expect(noConsent.presenter.gate == .consent)

        let ready = makeScreen()
        ready.presenter.onViewAppear()
        #expect(ready.presenter.gate == .chat)
    }

    @Test("Test Agreeing Opens The Chat And Declining Closes The Coach")
    func testConsent() async {
        let screen = makeScreen { $0.coachHasConsented = false }
        screen.presenter.onViewAppear()

        screen.presenter.onConsentAccepted()

        #expect(await TestManagers.eventually { screen.presenter.gate == .chat })
        #expect(screen.interactor.consentGiven == 1)

        let declined = makeScreen { $0.coachHasConsented = false }
        declined.presenter.onConsentDeclined()
        #expect(declined.router.shown == ["dismiss"])
    }

    // MARK: - Sending

    /// The question shows at once, the answer streams in, and the chat it started is kept for the
    /// next message.
    @Test("Test A Message Streams Its Answer And Keeps The Chat")
    func testSend() async {
        let screen = makeScreen(context: CoachContext(kind: .exercise, id: "bench", title: "Bench Press"))
        screen.presenter.onViewAppear()
        screen.presenter.draft = "  Is my bench progressing?  "

        screen.presenter.onSendPressed()

        #expect(await TestManagers.eventually { !screen.presenter.isSending })
        #expect(screen.presenter.messages.map(\.text) == ["Is my bench progressing?", "Hello there"])
        #expect(screen.presenter.messages.map(\.role) == [.user, .assistant])
        #expect(screen.presenter.streamingText == nil)
        #expect(screen.interactor.sent.first?.context?.id == "bench")
        #expect(screen.interactor.sent.first?.chatId == nil)

        screen.presenter.draft = "And squat?"
        screen.presenter.onSendPressed()
        #expect(await TestManagers.eventually { screen.interactor.sent.count == 2 })
        #expect(screen.interactor.sent.last?.chatId == "c1")
    }

    @Test("Test An Empty Message Is Not Sent")
    func testEmptyMessage() {
        let screen = makeScreen()
        screen.presenter.draft = "   "
        #expect(!screen.presenter.canSend)
        screen.presenter.onSendPressed()
        #expect(screen.interactor.sent.isEmpty)
    }

    /// A failed message comes back to the field so it can be sent again, and says why.
    @Test("Test A Failed Message Goes Back In The Field")
    func testFailedSend() async {
        let screen = makeScreen { $0.sendError = CoachError.dailyLimitReached }
        screen.presenter.draft = "How was my week?"

        screen.presenter.onSendPressed()

        #expect(await TestManagers.eventually { !screen.presenter.isSending })
        #expect(screen.presenter.messages.isEmpty)
        #expect(screen.presenter.draft == "How was my week?")
        #expect(screen.presenter.errorMessage == CoachError.dailyLimitReached.localizedDescription)
    }

    /// Consent withdrawn on another device, or premium lapsed: the function refuses, and the screen
    /// goes back to the gate rather than showing an error.
    @Test("Test A Refusal For Consent Or Premium Returns To The Gate")
    func testRefusalsReturnToGate() async {
        let consent = makeScreen { $0.sendError = CoachError.consentRequired }
        consent.presenter.draft = "hi"
        consent.presenter.onSendPressed()
        #expect(await TestManagers.eventually { consent.presenter.gate == .consent })

        let premium = makeScreen { $0.sendError = CoachError.premiumRequired }
        premium.presenter.draft = "hi"
        premium.presenter.onSendPressed()
        #expect(await TestManagers.eventually { premium.presenter.gate == .premium })
    }

    @Test("Test Suggested Questions Show Until The First Message And Send When Tapped")
    func testSuggestions() async {
        let screen = makeScreen(context: CoachContext(kind: .weightTrend))
        #expect(screen.presenter.suggestedQuestions == CoachContext(kind: .weightTrend).suggestedQuestions)

        screen.presenter.onSuggestedQuestionPressed(screen.presenter.suggestedQuestions[0])

        #expect(await TestManagers.eventually { !screen.presenter.isSending })
        #expect(screen.presenter.suggestedQuestions.isEmpty)
    }

    /// An opened chat shows what was said, and continues the same chat.
    @Test("Test An Opened Chat Shows Its Messages And Continues It")
    func testOpenedChat() async {
        let screen = makeScreen(chatId: "chat-1") { $0.coachChats = CoachChat.mocks }
        #expect(screen.presenter.messages.count == 2)
        #expect(screen.presenter.title == "Why has my weight stalled?")

        screen.presenter.draft = "And now?"
        screen.presenter.onSendPressed()
        #expect(await TestManagers.eventually { screen.interactor.sent.first?.chatId == "chat-1" })

        screen.presenter.onNewChatPressed()
        #expect(screen.presenter.messages.isEmpty)
    }

    @Test("Test The Few Messages Left Are Shown")
    func testRemaining() {
        let plenty = makeScreen { $0.coachRemainingToday = 40 }
        #expect(plenty.presenter.remainingText == nil)
        let few = makeScreen { $0.coachRemainingToday = 3 }
        #expect(few.presenter.remainingText == "3 coach messages left today")
    }

    /// The conversation is health data; analytics gets the context and nothing of the text.
    @Test("Test Analytics Never Carry The Message")
    func testAnalyticsCarryNoText() async {
        let screen = makeScreen()
        screen.presenter.draft = "My knee hurts"
        screen.presenter.onSendPressed()
        #expect(await TestManagers.eventually { !screen.presenter.isSending })

        let values = screen.interactor.lastParameters.values.flatMap { $0.values }.map { "\($0)" }
        #expect(!values.contains { $0.contains("knee") })
    }

    // MARK: - The function's refusals

    @Test("Test The Function's Refusals Read As The App's")
    func testErrorMapping() {
        func error(_ code: FunctionsErrorCode, reason: String? = nil) -> NSError {
            var info: [String: Any] = [:]
            if let reason { info[FunctionsErrorDetailsKey] = ["reason": reason] }
            return NSError(domain: FunctionsErrorDomain, code: code.rawValue, userInfo: info)
        }
        #expect(ProductionCoachService.coachError(from: error(.failedPrecondition, reason: "consent")) == .consentRequired)
        #expect(ProductionCoachService.coachError(from: error(.permissionDenied, reason: "premium")) == .premiumRequired)
        #expect(ProductionCoachService.coachError(from: error(.resourceExhausted, reason: "quota")) == .dailyLimitReached)
        #expect(ProductionCoachService.coachError(from: error(.unavailable)) == .unavailable)
        #expect(ProductionCoachService.coachError(from: URLError(.notConnectedToInternet)) == .unavailable)
    }

    // MARK: - The manager

    private func makeManager(service: CoachService = MockCoachService(), chats: [CoachChat] = []) async throws -> (CoachManager, UserManager) {
        let users = try await TestManagers.signedInUserManager(UserModel(userId: "me"))
        let manager = CoachManager(service: service, chatSyncEngine: TestManagers.collectionEngine(chats, key: "coach-chats"), users: users)
        await manager.signIn()
        return (manager, users)
    }

    @Test("Test Consent Is Given And Withdrawn, And Withdrawing Deletes Every Chat")
    func testManagerConsent() async throws {
        let (manager, users) = try await makeManager(chats: CoachChat.mocks)
        #expect(!manager.hasConsented)

        try await manager.giveConsent()
        #expect(await TestManagers.eventually { manager.hasConsented })
        #expect(users.privateSettings.coachConsentAt != nil)

        try await manager.withdrawConsent()
        #expect(await TestManagers.eventually { !manager.hasConsented && manager.chats.isEmpty })
        // Written as false, not removed: saves merge, so a removed field would keep its old value.
        #expect(users.privateSettings.coachConsent == false)
    }

    @Test("Test The Manager Passes The Stream On And Keeps The Day's Remaining Count")
    func testManagerSend() async throws {
        let (manager, _) = try await makeManager()
        var text = ""
        for try await event in manager.send(message: "hi", chatId: nil, context: .today) {
            if case .text(let delta) = event { text += delta }
        }
        #expect(!text.isEmpty)
        #expect(manager.remainingToday == 49)

        let (limited, _) = try await makeManager(service: MockCoachService(error: .dailyLimitReached))
        await #expect(throws: CoachError.dailyLimitReached) {
            for try await _ in limited.send(message: "hi", chatId: nil, context: nil) { }
        }
        #expect(limited.remainingToday == 0)
    }

    @Test("Test Chats Are Newest First")
    func testChatOrder() async throws {
        let now = Date()
        let older = CoachChat(id: "old", title: "Old", createdAt: now.addingTimeInterval(-100), updatedAt: now.addingTimeInterval(-100), contextKind: nil, messages: [])
        let newer = CoachChat(id: "new", title: "New", createdAt: now, updatedAt: now, contextKind: nil, messages: [])
        let (manager, _) = try await makeManager(chats: [older, newer])
        #expect(await TestManagers.eventually { manager.chats.map(\.id) == ["new", "old"] })
    }

    // MARK: - The chat list

    @Test("Test The Chat List Opens A Chat In Its Own Context And Withdraws After Asking")
    func testChatsList() async {
        let interactor = Interactor()
        interactor.coachChats = CoachChat.mocks
        let router = Router()
        let presenter = CoachChatsPresenter(interactor: interactor, router: router, delegate: CoachChatsDelegate())

        presenter.onChatPressed(CoachChat.mocks[0])
        #expect(router.openedChats.first?.chatId == "chat-1")
        #expect(router.openedChats.first?.context.kind == .weightTrend)
        #expect(router.openedChats.first?.showsCloseButton == false)

        presenter.onWithdrawPressed()
        #expect(router.dialogTitles == ["Withdraw Permission?"])
        #expect(interactor.consentWithdrawn == 0)
        presenter.onWithdrawConfirmed()
        #expect(await TestManagers.eventually { interactor.consentWithdrawn == 1 })

        presenter.onDelete(CoachChat.mocks[0])
        #expect(await TestManagers.eventually { interactor.deletedChatIds == ["chat-1"] })
    }

    // MARK: - Ways in

    @Test("Test Today Opens The Coach About Today And About The Protein Gap")
    func testTodayEntry() {
        let router = TodayPresenterTests.Router()
        let presenter = TodayPresenter(interactor: TodayPresenterTests.Interactor(), router: router, defaults: TestManagers.scratchDefaults("coach"))

        presenter.onAskCoachPressed()
        presenter.onProteinGapAskCoachPressed()

        #expect(router.coachContexts.map(\.kind) == [.today, .nutritionDay])
        #expect(router.coachContexts.last?.date == Date().dayKey)
    }
}
