//
//  CoachService.swift
//  Compound
//

import Foundation
import FirebaseFunctions

@MainActor
protocol CoachService {
    /// Sends one message and streams the answer. `chatId` nil starts a new chat.
    func send(message: String, chatId: String?, context: CoachContext?) -> AsyncThrowingStream<CoachStreamEvent, Error>
}

/// The `coachChat` callable, in `europe-west4` beside the Firestore data it reads.
struct ProductionCoachService: CoachService {

    private let functions = Functions.functions(region: "europe-west4")

    struct Request: Encodable, Sendable {
        let chatId: String?
        let message: String
        let context: Context?

        struct Context: Encodable, Sendable {
            let kind: String
            let id: String?
            let date: String?
        }
    }

    struct Chunk: Decodable, Sendable {
        let text: String
    }

    struct Result: Decodable, Sendable {
        let chatId: String
        let messageId: String
        let text: String
        let remainingToday: Int
    }

    func send(message: String, chatId: String?, context: CoachContext?) -> AsyncThrowingStream<CoachStreamEvent, Error> {
        let request = Request(
            chatId: chatId,
            message: message,
            context: context.map { Request.Context(kind: $0.kind.rawValue, id: $0.id, date: $0.date) }
        )
        var callable: Callable<Request, StreamResponse<Chunk, Result>> = functions.httpsCallable("coachChat")
        // Tools read history before the model answers; the default 70 seconds is tight for that.
        callable.timeoutInterval = 120
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await response in try callable.stream(request) {
                        switch response {
                        case .message(let chunk):
                            continuation.yield(.text(chunk.text))
                        case .result(let result):
                            continuation.yield(.finished(
                                chatId: result.chatId,
                                messageId: result.messageId,
                                text: result.text,
                                remainingToday: result.remainingToday
                            ))
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: Self.coachError(from: error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// The function's refusals carry a `reason` in their details; this reads them as the app's.
    static func coachError(from error: Error) -> CoachError {
        let nsError = error as NSError
        guard nsError.domain == FunctionsErrorDomain, let code = FunctionsErrorCode(rawValue: nsError.code) else {
            return .unavailable
        }
        let reason = (nsError.userInfo[FunctionsErrorDetailsKey] as? [String: Any])?["reason"] as? String
        switch code {
        case .failedPrecondition where reason == "consent": return .consentRequired
        case .permissionDenied where reason == "premium": return .premiumRequired
        case .resourceExhausted: return .dailyLimitReached
        case .unavailable, .deadlineExceeded, .internal, .unknown, .cancelled: return .unavailable
        default: return .failed(nsError.localizedDescription)
        }
    }
}

/// Answers word by word, as the real coach streams, for previews and the Mock scheme.
struct MockCoachService: CoachService {

    var error: CoachError?

    func send(message: String, chatId: String?, context: CoachContext?) -> AsyncThrowingStream<CoachStreamEvent, Error> {
        let answer = "Over the last four weeks you trained 3.5 times a week and your bench press estimated 1RM rose from 95 kg to 101 kg. Based on your 14 sessions since 7 September."
        let error = error
        return AsyncThrowingStream { continuation in
            let task = Task {
                if let error {
                    continuation.finish(throwing: error)
                    return
                }
                for word in answer.split(separator: " ") {
                    try? await Task.sleep(for: .milliseconds(30))
                    continuation.yield(.text("\(word) "))
                }
                continuation.yield(.finished(chatId: chatId ?? UUID().uuidString, messageId: UUID().uuidString, text: answer, remainingToday: 49))
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
