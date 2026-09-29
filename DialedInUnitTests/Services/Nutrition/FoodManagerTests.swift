//
//  FoodManagerTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 22/09/2026.
//

import Testing
import Foundation
@testable import DialedIn

/// The user's own food library.
///
/// Every meal item refers back to one of these by id, so a food that quietly changes or
/// disappears takes the meals that cite it with it. `image` is always nil here: the non-nil path
/// uploads through `FirebaseImageUploadService` directly, which no unit test can reach.
@MainActor
struct FoodManagerTests {

    private func food(
        id: String,
        name: String,
        nutrients: NutrientMap = [.calories: 100, .protein: 10]
    ) -> FoodModel {
        FoodModel(ingredientId: id, authorId: "user-1", name: name, nutrients: nutrients)
    }

    private var twoFoods: [FoodModel] {
        [food(id: "f1", name: "Oats"), food(id: "f2", name: "Milk")]
    }

    // MARK: - Reading

    @Test("Test Foods Are Empty Until Signed In")
    func testFoodsAreEmptyUntilSignedIn() {
        #expect(TestManagers.foodManager(foods: twoFoods).foods.isEmpty)
    }

    @Test("Test Signing In Exposes The Stored Foods")
    func testSigningInExposesTheStoredFoods() async {
        let manager = await TestManagers.signedInFoodManager(foods: twoFoods)

        #expect(manager.foods.map(\.id).sorted() == ["f1", "f2"])
    }

    @Test("Test Signing Out Empties The Library")
    func testSigningOutEmptiesTheLibrary() async {
        let manager = await TestManagers.signedInFoodManager(foods: twoFoods)
        #expect(manager.foods.count == 2)

        manager.signOut()

        // One account's foods must not still be on screen after another signs in.
        #expect(manager.foods.isEmpty)
    }

    // MARK: - Writing

    @Test("Test Saving A New Food Adds It")
    func testSavingANewFoodAddsIt() async throws {
        let manager = await TestManagers.signedInFoodManager(foods: [])

        try await manager.saveFood(food(id: "f3", name: "Chicken"), image: nil)

        #expect(await TestManagers.eventually { manager.foods.count == 1 })
        #expect(manager.foods.first?.name == "Chicken")
    }

    /// Editing a food is the same call as creating one, so the id has to replace rather than
    /// append — a duplicate would leave the meals that cite it pointing at either copy.
    @Test("Test Saving An Existing Food Replaces It Rather Than Duplicating")
    func testSavingAnExistingFoodReplacesItRatherThanDuplicating() async throws {
        let manager = await TestManagers.signedInFoodManager(foods: twoFoods)

        try await manager.saveFood(food(id: "f1", name: "Rolled Oats"), image: nil)

        #expect(await TestManagers.eventually { manager.foods.first(where: { $0.id == "f1" })?.name == "Rolled Oats" })
        #expect(manager.foods.count == 2)
    }

    @Test("Test Deleting A Food Removes It")
    func testDeletingAFoodRemovesIt() async throws {
        let manager = await TestManagers.signedInFoodManager(foods: twoFoods)

        try await manager.deleteFood(ingredientId: "f1")

        #expect(await TestManagers.eventually { manager.foods.count == 1 })
        #expect(manager.foods.map(\.id) == ["f2"])
    }

    // MARK: - Nutrients

    /// A saved food's nutrients are what every calorie figure in the app is computed from, so the
    /// manager must hand back exactly what it was given — including the distinction between a
    /// recorded zero and an unrecorded nutrient.
    @Test("Test A Food's Nutrients Come Back Unchanged")
    func testAFoodsNutrientsComeBackUnchanged() async throws {
        let manager = await TestManagers.signedInFoodManager(foods: [])
        let nutrients: NutrientMap = [
            .calories: 389,
            .protein: 16.9,
            .carbs: 66.3,
            .fatTotal: 6.9,
            .fiber: 10.6,
            .sodiumMg: 0,
            .vitaminB12Mcg: 0.0001
        ]

        try await manager.saveFood(food(id: "f9", name: "Oats", nutrients: nutrients), image: nil)
        #expect(await TestManagers.eventually { manager.foods.count == 1 })

        let saved = try #require(manager.foods.first)
        #expect(saved.nutrients == nutrients)
        #expect(saved.calories == 389)
        #expect(saved.nutrients[.sodiumMg] == 0)
        #expect(saved.nutrients[.calciumMg] == nil)
    }

    /// The wire format, which the manager's in-memory mock remote does not exercise.
    ///
    /// `NutrientMap` now drops anything non-finite on decode; real values must pass through it
    /// untouched, fractions and zeroes included.
    @Test("Test A Food Round Trips Through Its Stored Form")
    func testAFoodRoundTripsThroughItsStoredForm() throws {
        let original = food(
            id: "f10",
            name: "Greek Yoghurt",
            nutrients: [.calories: 59, .protein: 10.19, .carbs: 3.6, .fatTotal: 0.39, .calciumMg: 110]
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FoodModel.self, from: encoded)

        #expect(decoded.nutrients == original.nutrients)
        #expect(decoded.id == "f10")
        #expect(decoded.name == "Greek Yoghurt")
    }
}
