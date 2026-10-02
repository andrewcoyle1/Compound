import SwiftUI

@MainActor
protocol NutritionOverviewInteractor: GlobalInteractor {
    var userId: String? { get }
    var currentUser: UserModel? { get }
    func getDailyTotals(dayKey: String) throws -> DailyMacroTarget
    func getDailyNutritionBreakdown(dayKey: String) throws -> DailyNutritionBreakdown
    func getDailyTarget(for date: Date, userId: String) async throws -> DailyMacroTarget?
    func getMeals(for dayKey: String) throws -> [MealLogModel]
    var targetProposal: TargetProposal? { get }
    func acceptTargetProposal() async throws
    func dismissTargetProposal()
    var checkInState: CheckInState { get }
    func markCheckInSkipped(weekStart: Date) async throws
}

extension CoreInteractor: NutritionOverviewInteractor { }
