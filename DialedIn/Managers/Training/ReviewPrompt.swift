//
//  ReviewPrompt.swift
//  DialedIn
//
//  Asking for an App Store review after the third real workout, and offering the Dashboard's
//  one-time "Invite a friend" card after the fifth. Both run off one count kept on this device.
//

import Foundation

/// The decisions, pure so they can be tested without a device or StoreKit.
enum ReviewPromptPolicy {
    static let reviewAfterSessions = 3
    static let inviteAfterSessions = 5
    /// No second request inside this window, whether the first came from here or from Profile's
    /// "Rate us" row — both stamp the same date.
    static let cooldown: TimeInterval = 120 * 24 * 60 * 60

    /// A finished workout worth counting: not a pre-completed rest day, and at least one set done.
    static func counts(_ session: WorkoutSessionModel) -> Bool {
        !session.isRestDay && session.exercises.contains { exercise in
            exercise.sets.contains { $0.completedAt != nil }
        }
    }

    static func shouldRequestReview(completedSessions: Int, lastRequestedAt: Date, now: Date, isUITesting: Bool) -> Bool {
        !isUITesting
            && completedSessions >= reviewAfterSessions
            && now.timeIntervalSince(lastRequestedAt) >= cooldown
    }

    static func showsInviteCard(completedSessions: Int, inviteCardDismissed: Bool) -> Bool {
        !inviteCardDismissed && completedSessions >= inviteAfterSessions
    }
}

/// Where the count and the card's dismissal live.
struct ReviewPromptStore {
    static let completedSessionsKey = "review_prompt_completed_sessions"
    static let inviteCardDismissedKey = "review_prompt_invite_card_dismissed"

    var defaults: UserDefaults = .standard

    var completedSessions: Int { defaults.integer(forKey: Self.completedSessionsKey) }

    var inviteCardDismissed: Bool {
        get { defaults.bool(forKey: Self.inviteCardDismissedKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.inviteCardDismissedKey) }
    }

    /// Counts a saved session if it was a real one, and answers whether to ask for a review now.
    func recordFinishedSession(_ session: WorkoutSessionModel, lastRequestedAt: Date, now: Date = .now, isUITesting: Bool) -> Bool {
        guard ReviewPromptPolicy.counts(session) else { return false }
        let count = completedSessions + 1
        defaults.set(count, forKey: Self.completedSessionsKey)
        return ReviewPromptPolicy.shouldRequestReview(
            completedSessions: count,
            lastRequestedAt: lastRequestedAt,
            now: now,
            isUITesting: isUITesting
        )
    }
}

/// Called once a finished workout has saved.
@MainActor
func recordFinishedSessionForReviewPrompt(_ session: WorkoutSessionModel) {
    let shouldRequest = ReviewPromptStore().recordFinishedSession(
        session,
        lastRequestedAt: AppStoreRatingsHelper.lastRatingsRequestReviewDate,
        isUITesting: Utilities.isUITesting
    )
    if shouldRequest { AppStoreRatingsHelper.requestRatingsReview() }
}
