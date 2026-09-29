//
//  NotificationsRouter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol NotificationsRouter: GlobalRouter {
    func showWorkoutSessionDetailView(delegate: WorkoutSessionDetailDelegate)
    func showWorkoutSessionThreadPushed(delegate: WorkoutSessionDetailDelegate)
    func showSocialProfileView(delegate: SocialProfileDelegate)
    // MARK: - Sharing
    func showSharedItemView(delegate: SharedItemDelegate)
    // MARK: - Challenges
    func showChallengeDetailView(delegate: ChallengeDetailDelegate)

    // MARK: - Settings
    func showNotificationSettingsView(delegate: NotificationSettingsDelegate)
}

extension CoreRouter: NotificationsRouter { }

extension CoreRouter {
    /// The workout, pushed (not sheeted, so it carries no Close button of its own), with its
    /// comments pushed on top of that. `showWorkoutSessionThread` (used from the Dashboard feed)
    /// sheets both instead, which inside the Notifications sheet stacked a sheet on a sheet.
    func showWorkoutSessionThreadPushed(delegate: WorkoutSessionDetailDelegate) {
        router.showScreens(destinations: [
            AnyDestination(segue: .push) { router in
                builder.workoutSessionDetailView(router: router, delegate: delegate)
            },
            AnyDestination(segue: .push) { router in
                builder.commentsView(router: router, delegate: CommentsDelegate(session: delegate.initialSession))
            }
        ])
    }
}
