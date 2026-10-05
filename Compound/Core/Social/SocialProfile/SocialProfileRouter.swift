import SwiftUI

@MainActor
protocol SocialProfileRouter: GlobalRouter, ShareSheetRouter {
    func showFollowersList(delegate: FollowersListDelegate)
    func showWeeklyGoalView()
    func showSettingsView()
    func showEditProfileView(delegate: EditProfileDelegate)
}

extension CoreRouter: SocialProfileRouter { }
