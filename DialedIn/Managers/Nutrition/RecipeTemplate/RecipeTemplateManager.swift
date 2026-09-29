//
//  RecipeTemplateManager.swift
//  DialedIn
//
//  Created by Andrew Coyle on 24/09/2025.
//

import SwiftUI

@Observable
@MainActor
class RecipeTemplateManager {
    
    private let userRecipeTemplateSyncEngine: CollectionSyncEngine<RecipeTemplateModel>
    
    var userRecipeTemplates: [RecipeTemplateModel] {
        userRecipeTemplateSyncEngine.currentCollection
    }
    
    init(
        userRecipeTemplateSyncEngine: CollectionSyncEngine<RecipeTemplateModel>
    ) {
        self.userRecipeTemplateSyncEngine = userRecipeTemplateSyncEngine
    }
    
    func signIn() async {
        await userRecipeTemplateSyncEngine.startListening()
    }

    func signOut() {
        userRecipeTemplateSyncEngine.stopListening()
    }

    func saveRecipeTemplate(_ recipeTemplate: RecipeTemplateModel, image: PlatformImage?) async throws {
        var recipeTemplate = recipeTemplate
        if let image {
            let path = "recipe_templates/\(recipeTemplate.id)"
            let url = try await FirebaseImageUploadService().uploadImage(image: image, path: path)
            recipeTemplate.updateImageURL(imageUrl: url.absoluteString)
        }
        try await userRecipeTemplateSyncEngine.saveDocument(recipeTemplate)
    }
    
    func deleteRecipeTemplate(id: String) async throws {
        try await userRecipeTemplateSyncEngine.deleteDocument(id: id)
    }
}
 
extension CoreInteractor {
    // MARK: RecipeTemplateManager
    
    var userRecipeTemplates: [RecipeTemplateModel] {
        recipeTemplateManager.userRecipeTemplates
    }
    
    func saveRecipeTemplate(_ recipe: RecipeTemplateModel, image: PlatformImage?) async throws {
        try await recipeTemplateManager.saveRecipeTemplate(recipe, image: image)
    }
    
    func deleteRecipeTemplate(id: String) async throws {
        try await recipeTemplateManager.deleteRecipeTemplate(id: id)
    }
}
