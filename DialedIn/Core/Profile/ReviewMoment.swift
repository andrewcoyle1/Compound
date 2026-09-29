//
//  ReviewMoment.swift
//  DialedIn
//
//  When to ask for an App Store rating (decision 10d): Apple's prompt only, never a card of our
//  own, and only after something went well — the workout that completes the week's training goal,
//  or the food log that makes seven days in a row. The decision is pure so it can be tested; the
//  system call behind it cannot be.
//

import Foundation

enum ReviewMoment: Equatable {
    /// A workout was just finished; `sessionsThisWeek` includes it.
    case workoutFinished(sessionsThisWeek: Int, weeklyGoal: Int)
    /// Food was just logged; `daysInARow` counts today.
    case foodLogged(daysInARow: Int)

    static let foodStreakDays = 7

    /// Whether this moment is worth asking at. Only the workout that reaches the goal counts, not
    /// the ones after it, and only the seventh day, not every day after. The system shows the
    /// prompt at most three times a year; the cooldown keeps the app from asking more often than
    /// the Profile row and the existing workout prompt already share.
    static func shouldAsk(at moment: ReviewMoment, lastRequestedAt: Date, now: Date, isUITesting: Bool) -> Bool {
        guard !isUITesting, now.timeIntervalSince(lastRequestedAt) >= ReviewPromptPolicy.cooldown else { return false }
        switch moment {
        case let .workoutFinished(sessionsThisWeek, weeklyGoal):
            return weeklyGoal > 0 && sessionsThisWeek == weeklyGoal
        case let .foodLogged(daysInARow):
            return daysInARow == foodStreakDays
        }
    }

    /// How many days in a row, ending with `today`, have something logged. Zero when today has
    /// nothing.
    static func daysInARow(endingOn today: Date, loggedDays: [Date], calendar: Calendar = .current) -> Int {
        let days = Set(loggedDays.map { calendar.startOfDay(for: $0) })
        var day = calendar.startOfDay(for: today)
        var count = 0
        while days.contains(day), let previous = calendar.date(byAdding: .day, value: -1, to: day) {
            count += 1
            day = previous
        }
        return count
    }
}

/// Asks for a rating if `moment` has earned one. For the finishing code, which has no interactor.
@MainActor
func requestReviewIfEarned(_ moment: ReviewMoment) {
    guard ReviewMoment.shouldAsk(
        at: moment,
        lastRequestedAt: AppStoreRatingsHelper.lastRatingsRequestReviewDate,
        now: .now,
        isUITesting: Utilities.isUITesting
    ) else { return }
    AppStoreRatingsHelper.requestRatingsReview()
}

extension CoreInteractor {
    /// For presenters: asks for a rating if `moment` has earned one.
    func requestReviewIfEarned(_ moment: ReviewMoment) {
        DialedIn.requestReviewIfEarned(moment)
    }
}
