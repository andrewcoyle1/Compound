import SwiftUI

@MainActor
protocol FoodItemSearchInteractor: GlobalInteractor {
    func searchOpenFoodFacts(query: String) async throws -> [FoodModel]
    var recentFoods: [FoodModel] { get }
    /// The user's own saved foods, searched on-device alongside Open Food Facts.
    var foods: [FoodModel] { get }
    var foodLogSettings: FoodLogSettings { get }
}

extension CoreInteractor: FoodItemSearchInteractor {
    func searchOpenFoodFacts(query: String) async throws -> [FoodModel] {
        try await openFoodFactsService.searchFoods(query: query)
    }

    var recentFoods: [FoodModel] {
        var seenIds = Set<String>()
        var result: [FoodModel] = []
        for item in userMeals.ingredientItemsNewestFirst {
            guard seenIds.insert(item.sourceId).inserted else { continue }
            if let food = foods.first(where: { $0.id == item.sourceId }) {
                result.append(food)
                if result.count >= 20 { break }
            }
        }
        return result
    }
}
