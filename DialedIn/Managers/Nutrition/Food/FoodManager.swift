//
//  FoodManager.swift
//  DialedIn
//
//  Created by Andrew Coyle on 24/09/2025.
//

import SwiftUI

@Observable
@MainActor
class FoodManager {
    
    private let foodSyncEngine: CollectionSyncEngine<FoodModel>
    
    var foods: [FoodModel] {
        foodSyncEngine.currentCollection
    }
    
    init(foodSyncEngine: CollectionSyncEngine<FoodModel>) {
        self.foodSyncEngine = foodSyncEngine
    }
    
    func signIn() async {
        await foodSyncEngine.startListening()
    }
    
    func signOut() {
        foodSyncEngine.stopListening()
    }
    
    // MARK: - Method Aliases for Backward Compatibility
    
    func saveFood(_ ingredient: FoodModel, image: PlatformImage?) async throws {
        var ingredient = ingredient
        if let image {
            let path = "ingredient_templates/\(ingredient.id)"
            let url = try await FirebaseImageUploadService().uploadImage(image: image, path: path)
            ingredient.updateImageURL(imageUrl: url.absoluteString)
        }
        try await foodSyncEngine.saveDocument(ingredient)
    }
    
    func deleteFood(ingredientId id: String) async throws {
        try await foodSyncEngine.deleteDocument(id: id)
    }
}
 
extension CoreInteractor {
    // MARK: FoodManager
    
    var foods: [FoodModel] {
        foodManager.foods
    }
    
    func saveFood(_ ingredient: FoodModel, image: PlatformImage?) async throws {
        try await foodManager.saveFood(ingredient, image: image)
    }

    func deleteFood(ingredientId: String) async throws {
        try await foodManager.deleteFood(ingredientId: ingredientId)
    }
    }
