//
//  CoachManager.swift
//  Compound
//
//  The AI coach: a read-only chat about this account's own training, nutrition and body data,
//  answered by the `coachChat` Cloud Function, which reads the data itself. Premium only, after
//  the user agrees to share their data with the provider. See docs/specs/ai-coach.md.
//

import Foundation

@Observable
@MainActor
class CoachManager {

    private let service: CoachService
    private let chatSyncEngine: CollectionSyncEngine<CoachChat>
    private let users: UserManager

    /// What the function said was left of today's messages after the last answer; `nil` until one.
    private(set) var remainingToday: Int?

    /// The local-persistence name of the chats. Here rather than in `Keys` because it is not a
    /// secret, and must stay stable like the others.
    static let chatsManagerKey = "coach_chats"

    init(service: CoachService, chatSyncEngine: CollectionSyncEngine<CoachChat>, users: UserManager) {
        self.service = service
        self.chatSyncEngine = chatSyncEngine
        self.users = users
    }

    // MARK: - Lifecycle

    func signIn() async {
        await chatSyncEngine.startListening()
    }

    func signOut() {
        chatSyncEngine.stopListening()
        remainingToday = nil
    }

    // MARK: - Chats

    /// Newest first.
    var chats: [CoachChat] {
        chatSyncEngine.currentCollection.sorted { $0.updatedAt > $1.updatedAt }
    }

    func chat(id: String) -> CoachChat? {
        chatSyncEngine.currentCollection.first { $0.id == id }
    }

    func deleteChat(id: String) async throws {
        try await chatSyncEngine.deleteDocument(id: id)
    }

    // MARK: - Consent

    var hasConsented: Bool {
        users.privateSettings.coachConsent == true
    }

    func giveConsent() async throws {
        try await users.updatePrivateSettings {
            $0.coachConsent = true
            $0.coachConsentAt = .now
        }
    }

    /// Stops the coach reading anything, then deletes every chat. The flag goes first: a chat that
    /// failed to delete is worth less than consent that failed to be withdrawn.
    func withdrawConsent() async throws {
        try await users.updatePrivateSettings { $0.coachConsent = false }
        for chat in chatSyncEngine.currentCollection {
            try await chatSyncEngine.deleteDocument(id: chat.id)
        }
    }

    // MARK: - Asking

    /// Streams the answer to one message. The function stores both sides of the exchange, so the
    /// chat list catches up through its listener; the caller shows the stream meanwhile.
    func send(message: String, chatId: String?, context: CoachContext?) -> AsyncThrowingStream<CoachStreamEvent, Error> {
        let upstream = service.send(message: message, chatId: chatId, context: context)
        return AsyncThrowingStream { continuation in
            let task = Task { @MainActor in
                do {
                    for try await event in upstream {
                        if case .finished(_, _, _, let remaining) = event {
                            self.remainingToday = remaining
                        }
                        continuation.yield(event)
                    }
                    continuation.finish()
                } catch {
                    if case CoachError.dailyLimitReached = error { self.remainingToday = 0 }
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
