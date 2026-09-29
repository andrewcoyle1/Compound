import SwiftUI

@MainActor
protocol DashboardRouter: GlobalRouter, InviteAcceptRouter, ShareSheetRouter {
//    func showProfileView()
    func showProfileViewZoom(transitionId: String?, namespace: Namespace.ID)
    func showNotificationsView()
    func showNutritionView()
    func showAddMealView(delegate: AddMealDelegate)
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
    // MARK: - WeeklyReview
    func showWeeklyReviewView()
}

extension CoreRouter: DashboardRouter { }
