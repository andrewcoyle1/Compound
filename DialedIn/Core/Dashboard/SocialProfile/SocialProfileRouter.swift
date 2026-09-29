import SwiftUI

@MainActor
protocol SocialProfileRouter: GlobalRouter {
    func showFollowersList(delegate: FollowersListDelegate)
    func showWeeklyGoalView()
}

extension CoreRouter: SocialProfileRouter { }
