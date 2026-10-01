import SwiftUI

@MainActor
protocol RecipePreparationInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
    func saveRecipeTemplate(_ recipe: RecipeTemplateModel, image: PlatformImage?) async throws
}

extension CoreInteractor: RecipePreparationInteractor { }
