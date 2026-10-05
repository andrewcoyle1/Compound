import SwiftUI

@MainActor
protocol FoodItemSearchInteractor: GlobalInteractor {
    func searchOpenFoodFacts(query: String) async throws -> [FoodModel]
    var recentPicks: [RecentPick] { get }
    /// The user's own saved foods, searched on-device alongside Open Food Facts.
    var foods: [FoodModel] { get }
    /// The user's recipes, searched alongside their foods.
    var userRecipeTemplates: [RecipeTemplateModel] { get }
    var foodLogSettings: FoodLogSettings { get }
}

extension CoreInteractor: FoodItemSearchInteractor {
    func searchOpenFoodFacts(query: String) async throws -> [FoodModel] {
        try await openFoodFactsService.searchFoods(query: query)
    }

    var recentPicks: [RecentPick] {
        userMeals.recentPicks(foods: foods, recipes: userRecipeTemplates)
    }
}
