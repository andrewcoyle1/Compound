import SwiftUI

@MainActor
protocol WeeklyGoalInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
    func updateWeeklySessionGoal(_ goal: Int) async throws
}

extension CoreInteractor: WeeklyGoalInteractor { }
