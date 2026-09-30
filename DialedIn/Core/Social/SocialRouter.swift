import SwiftUI

@MainActor
protocol SocialRouter: GlobalRouter, InviteAcceptRouter, ShareSheetRouter {
    func showProfileViewZoom(transitionId: String?, namespace: Namespace.ID)
    func showNotificationsView()
    func showSocialProfileView(delegate: SocialProfileDelegate)
    func showWorkoutSessionDetailView(delegate: WorkoutSessionDetailDelegate)
    func showWorkoutSessionThread(delegate: WorkoutSessionDetailDelegate)
    func showEditUsernameView()
    func showWeeklyGoalView()
    #if DEV || MOCK
    func showDevSettingsView()
    #endif
    // MARK: - Challenges
    func showChallengeDetailView(delegate: ChallengeDetailDelegate)
    func showCreateChallengeView()
}

extension CoreRouter: SocialRouter { }
