//
//  CoachModels.swift
//  Compound
//
//  The AI coach's conversations, as the `coachChat` Cloud Function stores them in
//  `users/{uid}/coach_chats`, and what the app sends it. The function writes every chat; the app
//  only reads and deletes them. See docs/specs/ai-coach.md.
//

import Foundation

struct CoachChat: DataSyncModelProtocol, Equatable {
    let id: String
    let title: String
    let createdAt: Date
    let updatedAt: Date
    let contextKind: String?
    let messages: [CoachMessage]

    enum CodingKeys: String, CodingKey {
        case id, title, messages
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case contextKind = "context_kind"
    }

    static var mocks: [CoachChat] {
        let now = Date()
        return [
            CoachChat(
                id: "chat-1", title: "Why has my weight stalled?", createdAt: now.addingTimeInterval(-86_400),
                updatedAt: now.addingTimeInterval(-86_000), contextKind: CoachContext.Kind.weightTrend.rawValue,
                messages: [
                    CoachMessage(id: "m1", role: .user, text: "Why has my weight stalled?", createdAt: now.addingTimeInterval(-86_400)),
                    CoachMessage(
                        id: "m2", role: .assistant,
                        text: "Over the last three weeks you averaged 2,310 kcal against an estimated expenditure of 2,290 kcal, so you've been at maintenance. Based on your weigh-ins and meal logs since 14 September.",
                        createdAt: now.addingTimeInterval(-86_000)
                    )
                ]
            )
        ]
    }
}

struct CoachMessage: Codable, Equatable, Identifiable, Sendable {
    enum Role: String, Codable, Sendable {
        case user, assistant
    }

    let id: String
    let role: Role
    let text: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, role, text
        case createdAt = "created_at"
    }
}

/// Where the coach was opened from. The server uses it to start from the right data, and the chat
/// screen to suggest the first questions.
struct CoachContext: Equatable, Sendable {

    enum Kind: String, Codable, Sendable {
        case today
        case weightTrend = "weight_trend"
        case exercise
        case session
        case checkIn = "check_in"
        case nutritionDay = "nutrition_day"
        case weeklyReview = "weekly_review"
        case mesocycle
        case expenditure
        case muscleGroup = "muscle_group"
    }

    let kind: Kind
    /// The exercise template, session or muscle the screen is about.
    var id: String?
    /// The day, as `yyyy-MM-dd`, for a day's nutrition.
    var date: String?
    /// What the screen shows, for the chat's header: "Barbell Bench Press".
    var title: String?

    static let today = CoachContext(kind: .today)

    /// The questions offered before the first message.
    var suggestedQuestions: [String] {
        switch kind {
        case .today:
            return [
                String(localized: "How did my training go this week?"),
                String(localized: "What should I eat today to hit my protein?"),
                String(localized: "Am I on track for my goal?")
            ]
        case .weightTrend:
            return [
                String(localized: "Why has my weight changed this month?"),
                String(localized: "Am I losing at the rate I planned?"),
                String(localized: "What does my trend say about my calories?")
            ]
        case .exercise:
            return [
                String(localized: "Is this lift still progressing?"),
                String(localized: "Should I deload this exercise?"),
                String(localized: "What should I aim for next session?")
            ]
        case .session:
            return [
                String(localized: "How did this workout compare to last time?"),
                String(localized: "Did I set any records?"),
                String(localized: "What should I change next time?")
            ]
        case .checkIn:
            return [
                String(localized: "Why did my targets change?"),
                String(localized: "How did this week go?"),
                String(localized: "What should I focus on next week?")
            ]
        case .nutritionDay:
            return [
                String(localized: "How did I do against my targets?"),
                String(localized: "What can I eat to close my protein gap?"),
                String(localized: "Which meal had the most calories?")
            ]
        case .weeklyReview:
            return [
                String(localized: "Summarise my week"),
                String(localized: "What went well and what didn't?"),
                String(localized: "What should I change next week?")
            ]
        case .mesocycle:
            return [
                String(localized: "How is this block going?"),
                String(localized: "Am I recovering well enough?"),
                String(localized: "What should my next block focus on?")
            ]
        case .expenditure:
            return [
                String(localized: "How is my expenditure estimated?"),
                String(localized: "Why did my expenditure change?"),
                String(localized: "What should my calories be?")
            ]
        case .muscleGroup:
            return [
                String(localized: "Am I training this muscle enough?"),
                String(localized: "Which exercises hit this muscle?"),
                String(localized: "How has its volume changed?")
            ]
        }
    }
}

/// Why the coach could not answer, in the terms the chat screen acts on.
enum CoachError: LocalizedError, Equatable {
    /// No agreement to share data with the provider yet, or it was withdrawn.
    case consentRequired
    case premiumRequired
    /// The day's messages are used up.
    case dailyLimitReached
    case unavailable
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .consentRequired: return String(localized: "Allow the coach to read your data to continue.")
        case .premiumRequired: return String(localized: "The coach is part of Premium.")
        case .dailyLimitReached: return String(localized: "You've used today's coach messages. More tomorrow.")
        case .unavailable: return String(localized: "The coach isn't available right now. Try again in a moment.")
        case .failed: return String(localized: "The coach couldn't answer. Try again.")
        }
    }
}

/// One step of an answer as it streams: text as it arrives, then the stored result.
enum CoachStreamEvent: Equatable, Sendable {
    case text(String)
    case finished(chatId: String, messageId: String, text: String, remainingToday: Int)
}
