//
//  FoodModelCodableAndProtocolTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 25/10/2025.
//

import Testing
import Foundation
@testable import Compound

@MainActor
struct FoodCodableTests {

    // MARK: - Identifiable Tests
    
    @Test("Test FoodModel Is Identifiable")
    func testFoodModelIsIdentifiable() {
        let randomIngredientId = String.random
        let randomName = String.random
        let randomDate = Date.random
        
        let ingredient = FoodModel(
            ingredientId: randomIngredientId,
            name: randomName,
            nutrients: [.calories: 100.0, .protein: 10.0, .carbs: 50.0, .fatTotal: 5.0],
            dateCreated: randomDate,
            dateModified: randomDate
        )
        
        #expect(ingredient.id == randomIngredientId)
        #expect(ingredient.ingredientId == randomIngredientId)
    }
    
    // MARK: - Mutating Function Tests
    
    @Test("Test Update Image URL")
    func testUpdateImageURL() {
        let randomIngredientId = String.random
        let randomName = String.random
        let randomDate = Date.random
        let randomImageUrl = "https://example.com/\(String.random).jpg"
        
        var ingredient = FoodModel(
            ingredientId: randomIngredientId,
            name: randomName,
            nutrients: [.calories: 100.0, .protein: 10.0, .carbs: 50.0, .fatTotal: 5.0],
            dateCreated: randomDate,
            dateModified: randomDate
        )
        
        #expect(ingredient.imageURL == nil)
        
        ingredient.updateImageURL(imageUrl: randomImageUrl)
        
        #expect(ingredient.imageURL == randomImageUrl)
    }
    
    // MARK: - Codable Tests
    
    @Test("Test Encoding And Decoding")
    func testEncodingAndDecoding() throws {
        let randomIngredientId = String.random
        let randomName = String.random
        let randomAuthorId = String.random
        let randomDescription = String.random
        let randomImageUrl = "https://example.com/\(String.random).jpg"
        let randomDateCreated = Date.random
        let randomDateModified = Date.random
        
        let originalIngredient = FoodModel(
            ingredientId: randomIngredientId,
            authorId: randomAuthorId,
            name: randomName,
            description: randomDescription,
            measurementMethod: .weight,
            nutrients: [.calories: 250.0, .protein: 15.0, .carbs: 30.0, .fatTotal: 8.0, .fiber: 5.0, .sugar: 10.0],
            imageURL: randomImageUrl,
            dateCreated: randomDateCreated,
            dateModified: randomDateModified,
            clickCount: 10,
            bookmarkCount: 5,
            favouriteCount: 2
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let encodedData = try encoder.encode(originalIngredient)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let decodedIngredient = try decoder.decode(FoodModel.self, from: encodedData)
        
        // With millisecondsSince1970, dates preserve sub-second precision
        #expect(decodedIngredient.ingredientId == originalIngredient.ingredientId)
        #expect(decodedIngredient.authorId == originalIngredient.authorId)
        #expect(decodedIngredient.name == originalIngredient.name)
        #expect(decodedIngredient.description == originalIngredient.description)
        #expect(decodedIngredient.measurementMethod == originalIngredient.measurementMethod)
        #expect(decodedIngredient.calories == originalIngredient.calories)
        #expect(decodedIngredient.protein == originalIngredient.protein)
        #expect(decodedIngredient.carbs == originalIngredient.carbs)
        #expect(decodedIngredient.fatTotal == originalIngredient.fatTotal)
        #expect(abs(decodedIngredient.dateCreated.timeIntervalSince1970 - originalIngredient.dateCreated.timeIntervalSince1970) < 0.001)
        #expect(abs(decodedIngredient.dateModified.timeIntervalSince1970 - originalIngredient.dateModified.timeIntervalSince1970) < 0.001)
    }
    
    @Test("Test Coding Keys Mapping")
    func testCodingKeysMapping() throws {
        let randomIngredientId = String.random
        let randomName = String.random
        let randomAuthorId = String.random
        let randomDate = Date.random
        
        let ingredient = FoodModel(
            ingredientId: randomIngredientId,
            authorId: randomAuthorId,
            name: randomName,
            measurementMethod: .weight,
            nutrients: [.calories: 100.0, .protein: 10.0, .carbs: 50.0, .fatTotal: 5.0],
            dateCreated: randomDate,
            dateModified: randomDate
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let encodedData = try encoder.encode(ingredient)
        
        let json = try JSONSerialization.jsonObject(with: encodedData) as? [String: Any]
        
        #expect(json?["ingredient_id"] as? String == randomIngredientId)
        #expect(json?["author_id"] as? String == randomAuthorId)
        #expect(json?["name"] as? String == randomName)
        #expect(json?["measurement_method"] as? String == "weight")
        // The macros are no longer top-level keys: they are entries in `nutrients`, keyed by
        // `NutrientKey`'s raw values, which is what lets a food carry micronutrients too.
        let nutrients = json?["nutrients"] as? [String: Double]
        #expect(nutrients?["calories"] == 100.0)
        #expect(nutrients?["protein"] == 10.0)
        #expect(nutrients?["carbs"] == 50.0)
        #expect(nutrients?["fat_total"] == 5.0)
    }
    
    // MARK: - MeasurementMethod Enum Tests
    
    @Test("Test MeasurementMethod Raw Values")
    func testMeasurementMethodRawValues() {
        #expect(MeasurementMethod.weight.rawValue == "weight")
        #expect(MeasurementMethod.volume.rawValue == "volume")
    }
    
    @Test("Test MeasurementMethod CaseIterable")
    func testMeasurementMethodCaseIterable() {
        let allCases = MeasurementMethod.allCases
        #expect(allCases.count == 2)
        #expect(allCases.contains(.weight))
        #expect(allCases.contains(.volume))
    }
    
    // MARK: - Hashable Tests
    
    @Test("Test Hashable Conformance")
    func testHashableConformance() {
        let randomIngredientId = String.random
        let randomName = String.random
        let randomDate = Date.random
        
        let ingredient1 = FoodModel(
            ingredientId: randomIngredientId,
            name: randomName,
            nutrients: [.calories: 100.0, .protein: 10.0, .carbs: 50.0, .fatTotal: 5.0],
            dateCreated: randomDate,
            dateModified: randomDate
        )
        
        let ingredient2 = FoodModel(
            ingredientId: randomIngredientId,
            name: randomName,
            nutrients: [.calories: 100.0, .protein: 10.0, .carbs: 50.0, .fatTotal: 5.0],
            dateCreated: randomDate,
            dateModified: randomDate
        )
        
        var hashSet = Set<FoodModel>()
        hashSet.insert(ingredient1)
        hashSet.insert(ingredient2)
        
        // Should only have one element since they're equal
        #expect(hashSet.count == 1)
    }
}
