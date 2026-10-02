//
//  StravaOffer.swift
//  Compound
//
//  Strava left onboarding. It is offered once instead, over the session detail of the first
//  workout a person finishes, and never again after they answer.
//

import SwiftUI

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

extension CoreRouter {

    /// Run from the session detail shown after a workout is finished; `self` routes from that
    /// detail. Waits for the save (the detail appears before it lands), at most ten seconds, which
    /// also lets the sheet finish appearing before a dialog goes over it.
    func offerStravaIfFirstWorkout(_ finished: WorkoutSessionModel) async {
        let interactor = builder.interactor
        guard let userId = interactor.currentUser?.userId else { return }
        let key = StravaOffer.answeredKey(userId: userId)

        for _ in 0..<20 {
            do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
            if interactor.workoutSessions.contains(where: { $0.id == finished.id }) { break }
        }
        guard StravaOffer.shouldOffer(
            finished: finished,
            savedSessions: interactor.workoutSessions,
            isStravaConnected: interactor.stravaIsConnected,
            hasAnswered: UserDefaults.standard.bool(forKey: key)
        ) else { return }

        interactor.trackEvent(eventName: "strava_offer_shown", parameters: nil, type: .analytic)
        showConfirmationDialog(
            title: String(localized: "Upload Workouts to Strava?"),
            subtitle: String(localized: "Connect Strava and each workout you finish is added to it.")
        ) {
            AnyView(VStack {
                Button("Connect Strava") {
                    UserDefaults.standard.set(true, forKey: key)
                    interactor.trackEvent(eventName: "strava_offer_accepted", parameters: nil, type: .analytic)
                    self.connectStravaFromOffer()
                }
                Button("Not Now", role: .cancel) {
                    UserDefaults.standard.set(true, forKey: key)
                    interactor.trackEvent(eventName: "strava_offer_declined", parameters: nil, type: .analytic)
                }
            })
        }
    }

    /// The same sign-in Profile > Integrations runs, with the same answers.
    private func connectStravaFromOffer() {
        Task {
            do {
                try await builder.interactor.stravaAuthenticate()
            } catch where SignInCancellation.isCancellation(error) {
                // Closing Strava's sign-in page is a choice, not a failed connection.
            } catch StravaError.missingUploadPermission {
                showSimpleAlert(
                    title: String(localized: "Unable to Connect Strava"),
                    subtitle: StravaError.missingUploadPermission.localizedDescription
                )
            } catch {
                showSimpleAlert(
                    title: String(localized: "Unable to Connect Strava"),
                    subtitle: String(localized: "Check your internet connection and try again.")
                )
            }
        }
    }
}
