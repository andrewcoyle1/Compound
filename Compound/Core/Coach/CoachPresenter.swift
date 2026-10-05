//
//  CoachPresenter.swift
//  Compound
//

import SwiftUI

@Observable
@MainActor
class CoachPresenter {

    let interactor: CoachInteractor
    let router: CoachRouter
    let delegate: CoachDelegate

    enum Gate: Equatable {
        case premium
        case consent
        case chat
    }

    /// The conversation on screen: the stored chat when one was opened, then this session's turns.
    private(set) var messages: [CoachMessage] = []
    /// The answer as it streams in; `nil` when nothing is streaming.
    private(set) var streamingText: String?
    private(set) var chatId: String?
    private(set) var errorMessage: String?
    private(set) var isSending = false
    private(set) var isGivingConsent = false
    var draft = ""

    /// Moved off the gate only by what happens on this screen; read once from the managers on
    /// appear, so a refusal from the function (consent withdrawn on another device) can move it back.
    private(set) var gate: Gate = .chat

    init(interactor: CoachInteractor, router: CoachRouter, delegate: CoachDelegate) {
        self.interactor = interactor
        self.router = router
        self.delegate = delegate
        self.chatId = delegate.chatId
        if let chatId = delegate.chatId {
            messages = interactor.coachChat(id: chatId)?.messages ?? []
        }
    }

    var title: String {
        if let chatId, let chat = interactor.coachChat(id: chatId) { return chat.title }
        return delegate.context.title ?? String(localized: "Coach")
    }

    var suggestedQuestions: [String] {
        messages.isEmpty && streamingText == nil ? delegate.context.suggestedQuestions : []
    }

    /// Shown when few are left, so the limit is not a surprise.
    var remainingText: String? {
        guard let remaining = interactor.coachRemainingToday, remaining <= 10 else { return nil }
        return String(localized: "\(remaining) coach messages left today")
    }

    var canSend: Bool {
        !isSending && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear(context: delegate.context))
        gate = !interactor.isPremium ? .premium : (interactor.coachHasConsented ? .chat : .consent)
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    // MARK: - Gates

    func onSeePlansPressed() {
        interactor.trackEvent(event: Event.seePlansPressed)
        router.showPaywall(isOnboarding: false)
    }

    func onConsentAccepted() {
        guard !isGivingConsent else { return }
        isGivingConsent = true
        interactor.trackEvent(event: Event.consentStart)
        Task {
            defer { isGivingConsent = false }
            do {
                try await interactor.coachGiveConsent()
                interactor.trackEvent(event: Event.consentSuccess)
                interactor.playHaptic(option: .success)
                gate = .chat
            } catch {
                interactor.trackEvent(event: Event.consentFail(error: error))
                router.showFailure(String(localized: "Unable to Save Your Choice"), error: error)
            }
        }
    }

    func onConsentDeclined() {
        interactor.trackEvent(event: Event.consentDeclined)
        router.dismissScreen()
    }

    // MARK: - Chatting

    func onSuggestedQuestionPressed(_ question: String) {
        draft = question
        onSendPressed()
    }

    func onSendPressed() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        draft = ""
        errorMessage = nil
        isSending = true
        streamingText = ""
        let pending = CoachMessage(id: UUID().uuidString, role: .user, text: text, createdAt: .now)
        messages.append(pending)
        interactor.trackEvent(event: Event.sendStart(context: delegate.context, isNewChat: chatId == nil))

        Task {
            defer {
                isSending = false
                streamingText = nil
            }
            do {
                for try await event in interactor.coachSend(message: text, chatId: chatId, context: delegate.context) {
                    switch event {
                    case .text(let delta):
                        streamingText = (streamingText ?? "") + delta
                    case .finished(let chatId, let messageId, let answer, _):
                        self.chatId = chatId
                        messages.append(CoachMessage(id: messageId, role: .assistant, text: answer, createdAt: .now))
                    }
                }
                interactor.trackEvent(event: Event.sendSuccess)
            } catch {
                // The message did not go; it goes back in the field to try again.
                messages.removeAll { $0.id == pending.id }
                draft = text
                handle(error)
            }
        }
    }

    private func handle(_ error: Error) {
        interactor.trackEvent(event: Event.sendFail(error: error))
        interactor.playHaptic(option: .error)
        switch error as? CoachError {
        case .consentRequired: gate = .consent
        case .premiumRequired: gate = .premium
        default: errorMessage = (error as? CoachError ?? .unavailable).localizedDescription
        }
    }

    // MARK: - Toolbar

    func onNewChatPressed() {
        interactor.trackEvent(event: Event.newChatPressed)
        chatId = nil
        messages = []
        errorMessage = nil
    }

    func onChatsPressed() {
        interactor.trackEvent(event: Event.chatsPressed)
        router.showCoachChatsView(delegate: CoachChatsDelegate(context: delegate.context))
    }

    func onClosePressed() {
        router.dismissScreen()
    }
}

extension CoachPresenter {

    enum Event: LoggableEvent {
        case onAppear(context: CoachContext)
        case onDisappear
        case seePlansPressed
        case consentStart
        case consentSuccess
        case consentFail(error: Error)
        case consentDeclined
        case sendStart(context: CoachContext, isNewChat: Bool)
        case sendSuccess
        case sendFail(error: Error)
        case newChatPressed
        case chatsPressed

        var eventName: String {
            switch self {
            case .onAppear: return "CoachView_Appear"
            case .onDisappear: return "CoachView_Disappear"
            case .seePlansPressed: return "CoachView_SeePlans_Press"
            case .consentStart: return "CoachView_Consent_Start"
            case .consentSuccess: return "CoachView_Consent_Success"
            case .consentFail: return "CoachView_Consent_Fail"
            case .consentDeclined: return "CoachView_Consent_Declined"
            case .sendStart: return "CoachView_Send_Start"
            case .sendSuccess: return "CoachView_Send_Success"
            case .sendFail: return "CoachView_Send_Fail"
            case .newChatPressed: return "CoachView_NewChat_Press"
            case .chatsPressed: return "CoachView_Chats_Press"
            }
        }

        /// Never the message text: the conversation is the user's health data.
        var parameters: [String: Any]? {
            switch self {
            case .onAppear(let context): return ["context": context.kind.rawValue]
            case .sendStart(let context, let isNewChat): return ["context": context.kind.rawValue, "is_new_chat": isNewChat]
            case .consentFail(let error): return error.eventParameters
            case .sendFail(let error):
                return (error as? CoachError).map { ["reason": "\($0)"] } ?? error.eventParameters
            default: return nil
            }
        }

        var type: LogType {
            switch self {
            case .consentFail: return .severe
            case .sendFail: return .warning
            default: return .analytic
            }
        }
    }
}
