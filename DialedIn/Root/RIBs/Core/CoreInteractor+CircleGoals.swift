//
//  CoreInteractor+CircleGoals.swift
//  DialedIn
//

import Foundation

extension CoreInteractor {

    /// Written to the user's own document, which the owner can already update.
    func updateWeeklySessionGoal(_ goal: Int) async throws {
        try await userManager.updateUser(data: [UserModel.CodingKeys.weeklySessionGoal.rawValue: goal])
        refreshWidgetSnapshot(weeklyGoal: goal)
    }
}
