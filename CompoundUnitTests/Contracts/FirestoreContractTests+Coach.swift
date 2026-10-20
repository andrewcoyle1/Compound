//
//  FirestoreContractTests+Coach.swift
//  CompoundUnitTests
//
//  The AI coach's chats (`users/{uid}/coach_chats/{id}`) under the Firestore contract. Only the
//  `coachChat` function writes them; both apps read and delete them, so the contract holds the
//  function's shape to what Swift and Dart decode. The function writes `context_kind: null` for a
//  chat opened with no context, which `legacy-null-context-kind` covers. See
//  FirestoreContractTests.swift.
//

import Foundation
import Testing
import FirebaseFirestore
@testable import Compound

extension FirestoreContractTests {

    /// Every field: `coachChat` in functions/index.js writes the whole document by name, and reads
    /// `title`, `created_at`, `context_kind` and `messages` back when it appends a turn.
    static func coachContracts() throws -> [Contract] {
        [
            try contract(
                CoachChat.self, directory: "coach_chat",
                full: Samples.fullCoachChat, minimal: Samples.minimalCoachChat,
                namedFields: ([.id, .title, .createdAt, .updatedAt, .contextKind, .messages] as [CoachChat.CodingKeys])
                    .map(\.rawValue)
            )
        ]
    }

    /// Not CaseIterable, so listed here; the switch fails to compile on a new case.
    static func coachEnums() -> [String: [String]] {
        let roles: [CoachMessage.Role] = [.user, .assistant]
        for role in roles {
            switch role {
            case .user, .assistant: break
            }
        }
        return ["CoachMessageRole": roles.map(\.rawValue)]
    }
}

extension Samples {
    static let fullCoachChat = CoachChat(
        id: "chat_contract_full",
        title: "Why has my weight stalled?",
        createdAt: date("2026-10-12T08:15:30.250Z"),
        updatedAt: date("2026-10-12T08:16:02.500Z"),
        contextKind: CoachContext.Kind.weightTrend.rawValue,
        messages: [
            CoachMessage(id: "m_user", role: .user, text: "Why has my weight stalled?", createdAt: date("2026-10-12T08:15:30.250Z")),
            CoachMessage(
                id: "m_assistant", role: .assistant,
                text: "You averaged 2,310 kcal against an estimated 2,290 kcal, so you've been at maintenance.",
                createdAt: date("2026-10-12T08:16:02.500Z")
            )
        ]
    )

    static let minimalCoachChat = CoachChat(
        id: "chat_contract_minimal",
        title: "Hello",
        createdAt: date("2026-10-13T19:00:00.000Z"),
        updatedAt: date("2026-10-13T19:00:00.000Z"),
        contextKind: nil,
        messages: []
    )
}
