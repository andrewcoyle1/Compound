//
//  RecipeDetailInteractor.swift
//  DialedIn
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol RecipeDetailInteractor {
    var currentUser: UserModel? { get }
    func isFavouriteRecipe(id: String) -> Bool
    func setFavouriteRecipe(id: String, isFavourite: Bool) async throws
    func deleteRecipeTemplate(id: String) async throws
}

extension CoreInteractor: RecipeDetailInteractor { }
