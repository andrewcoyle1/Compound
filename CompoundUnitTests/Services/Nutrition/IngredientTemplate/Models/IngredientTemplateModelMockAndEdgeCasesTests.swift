//
//  FoodModelMockAndEdgeCasesTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 25/10/2025.
//

import Testing
import Foundation
@testable import Compound

@MainActor
struct FoodMockTests {

    // MARK: - Mock Tests
    
    @Test("Test Mock Property")
    func testMockProperty() {
        let mock = FoodModel.mock
        
        #expect(mock.ingredientId == "ing-1")
        #expect(mock.name == "Rolled Oats")
        #expect(mock.calories == 389)
        #expect(mock.protein == 16.9)
        #expect(mock.carbs == 66.3)
        #expect(mock.fatTotal == 6.9)
    }
    
    @Test("Test Mocks Property")
    func testMocksProperty() {
        let mocks = FoodModel.mocks
        let names = mocks.map(\.name)
        let allNamed = mocks.allSatisfy { !$0.name.isEmpty }
        let idsAreUnique = Set(mocks.map(\.ingredientId)).count == mocks.count
        
        // Pinned loosely: the mock pantry has grown from two foods to six, and will grow again.
        #expect(mocks.count >= 2)
        #expect(names.contains("Rolled Oats"))
        #expect(names.contains("Whole Milk"))
        #expect(allNamed)
        #expect(idsAreUnique)
    }
    
    @Test("Test Mocks Have Different Measurement Methods")
    func testMocksHaveDifferentMeasurementMethods() {
        let mocks = FoodModel.mocks
        
        #expect(mocks[0].measurementMethod == .weight)
        #expect(mocks[1].measurementMethod == .volume)
    }
    
    @Test("Test Mocks Have Different Author IDs")
    func testMocksHaveDifferentAuthorIds() {
        let mocks = FoodModel.mocks
        
        #expect(mocks[0].authorId == "1")
        #expect(mocks[1].authorId == "2")
    }
    
    // MARK: - Event Parameters Tests
    
    @Test("Test Event Parameters")
    func testEventParameters() {
        let randomIngredientId = String.random
        let randomAuthorId = String.random
        let randomName = String.random
        let randomDate = Date.random
        
        let ingredient = FoodModel(
            ingredientId: randomIngredientId,
            authorId: randomAuthorId,
            name: randomName,
            measurementMethod: .weight,
            nutrients: [.calories: 250.0, .protein: 15.0, .carbs: 30.0, .fatTotal: 8.0],
            dateCreated: randomDate,
            dateModified: randomDate,
            clickCount: 10,
            bookmarkCount: 5,
            favouriteCount: 2
        )
        
        let eventParams = ingredient.eventParameters
        
        #expect(eventParams["user_ingredient_id"] as? String == randomIngredientId)
        #expect(eventParams["user_author_id"] as? String == randomAuthorId)
        #expect(eventParams["user_name"] as? String == randomName)
        #expect(eventParams["user_measurement_method"] as? String == "weight")
        #expect(eventParams["user_calories"] as? Double == 250.0)
        #expect(eventParams["user_protein"] as? Double == 15.0)
        #expect(eventParams["user_carbs"] as? Double == 30.0)
        #expect(eventParams["user_fat_total"] as? Double == 8.0)
    }
    
    @Test("Test Event Parameters Filters Nil Values")
    func testEventParametersFiltersNilValues() {
        let randomIngredientId = String.random
        let randomName = String.random
        let randomDate = Date.random
        
        let ingredient = FoodModel(
            ingredientId: randomIngredientId,
            authorId: nil,
            name: randomName,
            description: nil,
            nutrients: [.calories: 100.0, .protein: 10.0, .carbs: 50.0, .fatTotal: 5.0],
            dateCreated: randomDate,
            dateModified: randomDate
        )
        
        let eventParams = ingredient.eventParameters
        
        #expect(eventParams["user_ingredient_id"] as? String == randomIngredientId)
        #expect(eventParams["user_author_id"] == nil)
        #expect(eventParams["user_description"] == nil)
    }
    
    // MARK: - Edge Cases
    
    @Test("Test Zero Nutritional Values")
    func testZeroNutritionalValues() {
        let randomIngredientId = String.random
        let randomName = String.random
        let randomDate = Date.random
        
        let ingredient = FoodModel(
            ingredientId: randomIngredientId,
            name: randomName,
            nutrients: [.calories: 0.0, .protein: 0.0, .carbs: 0.0, .fatTotal: 0.0],
            dateCreated: randomDate,
            dateModified: randomDate
        )
        
        #expect(ingredient.calories == 0.0)
        #expect(ingredient.protein == 0.0)
        #expect(ingredient.carbs == 0.0)
        #expect(ingredient.fatTotal == 0.0)
    }
    
    @Test("Test Very Large Nutritional Values")
    func testVeryLargeNutritionalValues() {
        let randomIngredientId = String.random
        let randomName = String.random
        let randomDate = Date.random
        
        let ingredient = FoodModel(
            ingredientId: randomIngredientId,
            name: randomName,
            nutrients: [.calories: 9999.99, .protein: 999.99, .carbs: 999.99, .fatTotal: 999.99],
            dateCreated: randomDate,
            dateModified: randomDate
        )
        
        #expect(ingredient.calories == 9999.99)
        #expect(ingredient.protein == 999.99)
        #expect(ingredient.carbs == 999.99)
        #expect(ingredient.fatTotal == 999.99)
    }
    
    @Test("Test Empty Name")
    func testEmptyName() {
        let randomIngredientId = String.random
        let randomDate = Date.random
        
        let ingredient = FoodModel(
            ingredientId: randomIngredientId,
            name: "",
            nutrients: [.calories: 100.0, .protein: 10.0, .carbs: 50.0, .fatTotal: 5.0],
            dateCreated: randomDate,
            dateModified: randomDate
        )
        
        #expect(ingredient.name.isEmpty)
    }
    
    @Test("Test Very Long Name")
    func testVeryLongName() {
        let randomIngredientId = String.random
        let longName = String(repeating: "a", count: 1000)
        let randomDate = Date.random
        
        let ingredient = FoodModel(
            ingredientId: randomIngredientId,
            name: longName,
            nutrients: [.calories: 100.0, .protein: 10.0, .carbs: 50.0, .fatTotal: 5.0],
            dateCreated: randomDate,
            dateModified: randomDate
        )
        
        #expect(ingredient.name.count == 1000)
    }
}
