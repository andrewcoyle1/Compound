//
//  StravaOffer.swift
//  Compound
//
//  Strava left onboarding. It is offered once instead, over the session detail of the first
//  workout a person finishes, and never again after they answer. The rule; the summary's
//  presenter asks it (`WorkoutSessionDetailPresenter.onSummaryTask`).
//

import Foundation

enum StravaOffer {

    /// Per person, so a second account on the same phone gets its own offer.
    static func answeredKey(userId: String) -> String { "strava_offer_answered_\(userId)" }

    /// Whether `finished` is the moment to offer: Strava is not connected, the offer has not been
    /// answered, `finished` has saved, and no other finished workout of the same author exists.
    /// Rest days and deleted sessions are not workouts the person finished.
    static func shouldOffer(
        finished: WorkoutSessionModel,
        savedSessions: [WorkoutSessionModel],
        isStravaConnected: Bool,
        hasAnswered: Bool
    ) -> Bool {
        guard !isStravaConnected, !hasAnswered, isFinishedWorkout(finished),
              savedSessions.contains(where: { $0.id == finished.id }) else { return false }
        return !savedSessions.contains { $0.id != finished.id && $0.authorId == finished.authorId && isFinishedWorkout($0) }
    }

    private static func isFinishedWorkout(_ session: WorkoutSessionModel) -> Bool {
        session.endedAt != nil && !session.isRestDay && session.deletedAt == nil
    }
}
