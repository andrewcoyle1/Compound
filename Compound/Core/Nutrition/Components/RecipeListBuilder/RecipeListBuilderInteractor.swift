import SwiftUI

@MainActor
protocol RecipeListBuilderInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
    var userRecipeTemplates: [RecipeTemplateModel] { get }
    var userMeals: [MealLogModel] { get }
    var foodLogSettings: FoodLogSettings { get }
}

extension CoreInteractor: RecipeListBuilderInteractor { }
