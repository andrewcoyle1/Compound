import SwiftUI

@MainActor
protocol FoodLibraryInteractor: GlobalInteractor {
    var foods: [FoodModel] { get }
    var userRecipeTemplates: [RecipeTemplateModel] { get }
    var foodLogSettings: FoodLogSettings { get }
}

extension CoreInteractor: FoodLibraryInteractor { }
