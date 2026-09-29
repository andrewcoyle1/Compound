//
//  RecipeTemplateManagerTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 22/09/2026.
//

import Testing
import Foundation
@testable import DialedIn

/// The user's own recipes.
///
/// A recipe embeds a whole copy of each ingredient rather than its id, which decides how it
/// behaves when the food library changes underneath it — the case this suite spends most of its
/// time on.
@MainActor
struct RecipeTemplateManagerTests {

    private func food(id: String, name: String, nutrients: NutrientMap = [.calories: 100]) -> FoodModel {
        FoodModel(ingredientId: id, authorId: "user-1", name: name, nutrients: nutrients)
    }

    private func recipe(
        id: String,
        name: String,
        ingredients: [RecipeIngredientModel] = [],
        steps: [String] = []
    ) -> RecipeTemplateModel {
        RecipeTemplateModel(
            id: id,
            authorId: "user-1",
            name: name,
            dateCreated: Date(timeIntervalSince1970: 1_700_000_000),
            dateModified: Date(timeIntervalSince1970: 1_700_000_000),
            ingredients: ingredients,
            preparationSteps: steps
        )
    }

    private var twoRecipes: [RecipeTemplateModel] {
        [recipe(id: "r1", name: "Porridge"), recipe(id: "r2", name: "Omelette")]
    }

    // MARK: - Reading

    @Test("Test Recipes Are Empty Until Signed In")
    func testRecipesAreEmptyUntilSignedIn() {
        #expect(TestManagers.recipeTemplateManager(recipes: twoRecipes).userRecipeTemplates.isEmpty)
    }

    @Test("Test Signing In Exposes The Stored Recipes")
    func testSigningInExposesTheStoredRecipes() async {
        let manager = await TestManagers.signedInRecipeTemplateManager(recipes: twoRecipes)

        #expect(manager.userRecipeTemplates.map(\.id).sorted() == ["r1", "r2"])
    }

    @Test("Test Signing Out Empties The Recipes")
    func testSigningOutEmptiesTheRecipes() async {
        let manager = await TestManagers.signedInRecipeTemplateManager(recipes: twoRecipes)
        #expect(manager.userRecipeTemplates.count == 2)

        manager.signOut()

        #expect(manager.userRecipeTemplates.isEmpty)
    }

    // MARK: - Writing

    @Test("Test Saving A New Recipe Adds It")
    func testSavingANewRecipeAddsIt() async throws {
        let manager = await TestManagers.signedInRecipeTemplateManager(recipes: [])

        try await manager.saveRecipeTemplate(recipe(id: "r3", name: "Chilli"), image: nil)

        #expect(await TestManagers.eventually { manager.userRecipeTemplates.count == 1 })
        #expect(manager.userRecipeTemplates.first?.name == "Chilli")
    }

    @Test("Test Saving An Existing Recipe Replaces It Rather Than Duplicating")
    func testSavingAnExistingRecipeReplacesItRatherThanDuplicating() async throws {
        let manager = await TestManagers.signedInRecipeTemplateManager(recipes: twoRecipes)

        try await manager.saveRecipeTemplate(recipe(id: "r1", name: "Overnight Oats"), image: nil)

        #expect(await TestManagers.eventually {
            manager.userRecipeTemplates.first(where: { $0.id == "r1" })?.name == "Overnight Oats"
        })
        #expect(manager.userRecipeTemplates.count == 2)
    }

    /// Ingredients and steps are the recipe, so an edit that saved the name and lost the body
    /// would be the worst kind of quiet failure.
    @Test("Test A Recipe's Ingredients And Steps Come Back Unchanged")
    func testARecipesIngredientsAndStepsComeBackUnchanged() async throws {
        let manager = await TestManagers.signedInRecipeTemplateManager(recipes: [])
        let ingredients = [
            RecipeIngredientModel(ingredient: food(id: "f1", name: "Oats"), amount: 80, unit: .grams),
            RecipeIngredientModel(ingredient: food(id: "f2", name: "Milk"), amount: 250, unit: .milliliters)
        ]

        try await manager.saveRecipeTemplate(
            recipe(id: "r4", name: "Porridge", ingredients: ingredients, steps: ["Boil", "Stir"]),
            image: nil
        )
        #expect(await TestManagers.eventually { manager.userRecipeTemplates.count == 1 })

        let saved = try #require(manager.userRecipeTemplates.first)
        #expect(saved.ingredients.map(\.id) == ["f1", "f2"])
        #expect(saved.ingredients.map(\.amount) == [80, 250])
        #expect(saved.ingredients.map(\.unit) == [.grams, .milliliters])
        #expect(saved.preparationSteps == ["Boil", "Stir"])
        #expect(saved.ingredients.first?.ingredient.nutrients[.calories] == 100)
    }

    @Test("Test Deleting A Recipe Removes It")
    func testDeletingARecipeRemovesIt() async throws {
        let manager = await TestManagers.signedInRecipeTemplateManager(recipes: twoRecipes)

        try await manager.deleteRecipeTemplate(id: "r1")

        #expect(await TestManagers.eventually { manager.userRecipeTemplates.count == 1 })
        #expect(manager.userRecipeTemplates.map(\.id) == ["r2"])
    }

    // MARK: - A recipe whose food is deleted

    /// The consequence of embedding the food rather than referring to it: deleting the food from
    /// the library leaves the recipe whole and still cookable.
    ///
    /// The trade is that the recipe's copy then stops tracking the library — an edit to the food
    /// afterwards does not reach it. That is the right way round for a recipe, whose ingredient
    /// list should not change under the user, but it does mean the two can drift.
    @Test("Test Deleting A Food Leaves A Recipe That Uses It Intact")
    func testDeletingAFoodLeavesARecipeThatUsesItIntact() async throws {
        let oats = food(id: "f1", name: "Oats", nutrients: [.calories: 389, .protein: 16.9])
        let foodManager = await TestManagers.signedInFoodManager(foods: [oats])
        let recipeManager = await TestManagers.signedInRecipeTemplateManager(recipes: [
            recipe(
                id: "r1",
                name: "Porridge",
                ingredients: [RecipeIngredientModel(ingredient: oats, amount: 80, unit: .grams)]
            )
        ])

        try await foodManager.deleteFood(ingredientId: "f1")
        #expect(await TestManagers.eventually { foodManager.foods.isEmpty })

        let survivor = try #require(recipeManager.userRecipeTemplates.first)
        #expect(survivor.ingredients.count == 1)
        #expect(survivor.ingredients.first?.name == "Oats")
        #expect(survivor.ingredients.first?.ingredient.nutrients[.calories] == 389)
    }

    /// The other half of that trade, stated so nobody assumes otherwise: renaming a food in the
    /// library does not rename it inside recipes already built from it.
    @Test("Test Editing A Food Does Not Reach Recipes Already Built From It")
    func testEditingAFoodDoesNotReachRecipesAlreadyBuiltFromIt() async throws {
        let oats = food(id: "f1", name: "Oats")
        let foodManager = await TestManagers.signedInFoodManager(foods: [oats])
        let recipeManager = await TestManagers.signedInRecipeTemplateManager(recipes: [
            recipe(
                id: "r1",
                name: "Porridge",
                ingredients: [RecipeIngredientModel(ingredient: oats, amount: 80, unit: .grams)]
            )
        ])

        try await foodManager.saveFood(food(id: "f1", name: "Jumbo Oats"), image: nil)
        #expect(await TestManagers.eventually { foodManager.foods.first?.name == "Jumbo Oats" })

        #expect(recipeManager.userRecipeTemplates.first?.ingredients.first?.name == "Oats")
    }

    /// The wire format for the embedded ingredient list, which the in-memory mock remote skips.
    @Test("Test A Recipe Round Trips Through Its Stored Form")
    func testARecipeRoundTripsThroughItsStoredForm() throws {
        let original = recipe(
            id: "r5",
            name: "Porridge",
            ingredients: [RecipeIngredientModel(ingredient: food(id: "f1", name: "Oats"), amount: 80, unit: .grams)],
            steps: ["Boil"]
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RecipeTemplateModel.self, from: encoded)

        #expect(decoded.id == "r5")
        #expect(decoded.ingredients.map(\.amount) == [80])
        #expect(decoded.ingredients.first?.ingredient.nutrients == original.ingredients.first?.ingredient.nutrients)
        #expect(decoded.preparationSteps == ["Boil"])
        #expect(decoded.servingQuantity == original.servingQuantity)
    }

    // MARK: - A corrupt stored amount

    /// `RecipeDetailView` and `RecipeStartView` print an ingredient's amount through `Int(_:)` from
    /// a view body, which traps on a value that is not finite. `RecipeIngredientModel.init(from:)`
    /// guards that by clamping a non-finite decoded amount to zero rather than letting it through —
    /// unlike a corrupt nutrient, which `NutrientMap` drops outright, because an ingredient has to
    /// have *some* amount and zero is what an emptied field already means.
    private var lenientDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: "inf",
            negativeInfinity: "-inf",
            nan: "nan"
        )
        return decoder
    }

    @Test("Test A Stored NaN Ingredient Amount Reads As Zero Rather Than Trapping")
    func testAStoredNaNIngredientAmountReadsAsZeroRatherThanTrapping() throws {
        let ingredientData = try JSONEncoder().encode(food(id: "f1", name: "Oats"))
        let ingredientObject = try JSONSerialization.jsonObject(with: ingredientData)

        let json: [String: Any] = ["ingredient": ingredientObject, "amount": "nan", "unit": "grams"]
        let data = try JSONSerialization.data(withJSONObject: json)

        let decoded = try lenientDecoder.decode(RecipeIngredientModel.self, from: data)

        #expect(decoded.amount == 0)
        #expect(decoded.name == "Oats")
    }

    @Test("Test A Stored Infinite Ingredient Amount Reads As Zero")
    func testAStoredInfiniteIngredientAmountReadsAsZero() throws {
        let ingredientData = try JSONEncoder().encode(food(id: "f1", name: "Oats"))
        let ingredientObject = try JSONSerialization.jsonObject(with: ingredientData)

        let json: [String: Any] = ["ingredient": ingredientObject, "amount": "inf", "unit": "grams"]
        let data = try JSONSerialization.data(withJSONObject: json)

        let decoded = try lenientDecoder.decode(RecipeIngredientModel.self, from: data)

        #expect(decoded.amount == 0)
    }

    /// The other half of the guard: an absurdly large but finite amount is capped rather than left
    /// to multiply a per-100g nutrient up to infinity later.
    @Test("Test A Stored Amount Past The Ceiling Is Capped Rather Than Left Absurd")
    func testAStoredAmountPastTheCeilingIsCappedRatherThanLeftAbsurd() throws {
        let ingredientData = try JSONEncoder().encode(food(id: "f1", name: "Oats"))
        let ingredientObject = try JSONSerialization.jsonObject(with: ingredientData)

        let json: [String: Any] = ["ingredient": ingredientObject, "amount": 50_000_000, "unit": "grams"]
        let data = try JSONSerialization.data(withJSONObject: json)

        let decoded = try JSONDecoder().decode(RecipeIngredientModel.self, from: data)

        #expect(decoded.amount == 1_000_000)
    }
}
