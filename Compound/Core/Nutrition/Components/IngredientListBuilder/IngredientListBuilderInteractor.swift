import SwiftUI

@MainActor
protocol IngredientListBuilderInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
    var foods: [FoodModel] { get }
    var userMeals: [MealLogModel] { get }
    var foodLogSettings: FoodLogSettings { get }
}

extension CoreInteractor: IngredientListBuilderInteractor { }
