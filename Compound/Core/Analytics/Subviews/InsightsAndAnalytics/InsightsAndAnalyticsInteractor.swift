import SwiftUI

@MainActor
protocol InsightsAndAnalyticsInteractor: GlobalInteractor {
    var auth: UserAuthInfo? { get }
    var currentUser: UserModel? { get }
    var bodyMeasurements: [BodyMeasurementEntry] { get }
    var currentGoal: WeightGoal? { get }
    var workoutSessions: [WorkoutSessionModel] { get }
    func getDailyTotals(dayKey: String) throws -> DailyMacroTarget
    func estimateTDEE(user: UserModel?) -> Double
    var expenditureHistory: [ExpenditureEstimate] { get }
}

extension CoreInteractor: InsightsAndAnalyticsInteractor { }
