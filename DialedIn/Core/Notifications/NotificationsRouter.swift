//
//  NotificationsRouter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol NotificationsRouter: GlobalRouter {
    func showWorkoutSessionDetailView(delegate: WorkoutSessionDetailDelegate)
    func showWorkoutSessionThread(delegate: WorkoutSessionDetailDelegate)
    func showSocialProfileView(delegate: SocialProfileDelegate)
    // MARK: - Sharing
    func showSharedItemView(delegate: SharedItemDelegate)
    // MARK: - Challenges
    func showChallengeDetailView(delegate: ChallengeDetailDelegate)
}

extension CoreRouter: NotificationsRouter { }
