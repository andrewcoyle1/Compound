import SwiftUI

@MainActor
protocol TimelineActionsInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
    var foodLogSettings: FoodLogSettings { get }
    func saveFoodLogSettings(_ settings: FoodLogSettings) async throws
    func getMeals(for dayKey: String) throws -> [MealLogModel]
    func saveMeal(_ meal: MealLogModel) async throws
    func deleteMealAndSync(id: String, dayKey: String, authorId: String) async throws
}

extension CoreInteractor: TimelineActionsInteractor { }
