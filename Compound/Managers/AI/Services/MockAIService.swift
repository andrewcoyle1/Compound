//
//  MockAIService.swift
//  Compound
//
//  Created by Andrew Coyle on 10/15/24.
//
import SwiftUI

struct MockAIService: AIService {
    
    let delay: Double
    let showError: Bool
    
    init(delay: Double = 0.0, showError: Bool = false) {
        self.delay = delay
        self.showError = showError
    }
    
    private func tryShowError() throws {
        if showError {
            throw URLError(.unknown)
        }
    }
    
    func generateImage(input: String) async throws -> UIImage {
        try await Task.sleep(for: .seconds(delay))
        try tryShowError()
        return UIImage(systemName: "star.fill")!
    }
    
    func analyzeFood(imageData: Data) async throws -> String {
        try await Task.sleep(for: .seconds(delay))
        try tryShowError()
        return """
        {"items":[
          {"id":"1","name":"Grilled Chicken Breast","amountGrams":150,"calories":248,"proteinGrams":46.5,"carbGrams":0,"fatGrams":5.4},
          {"id":"2","name":"Brown Rice","amountGrams":100,"calories":111,"proteinGrams":2.6,"carbGrams":23,"fatGrams":0.9},
          {"id":"3","name":"Steamed Broccoli","amountGrams":80,"calories":27,"proteinGrams":2.4,"carbGrams":5,"fatGrams":0.3}
        ]}
        """
    }

    func describeMeal(text: String) async throws -> String {
        try await Task.sleep(for: .seconds(delay))
        try tryShowError()
        return """
        {"items":[
          {"id":"1","name":"Grilled Chicken Breast","amountGrams":150,"calories":248,"proteinGrams":46.5,"carbGrams":0,"fatGrams":5.4},
          {"id":"2","name":"Brown Rice","amountGrams":100,"calories":111,"proteinGrams":2.6,"carbGrams":23,"fatGrams":0.9},
          {"id":"3","name":"Steamed Broccoli","amountGrams":80,"calories":27,"proteinGrams":2.4,"carbGrams":5,"fatGrams":0.3}
        ]}
        """
    }

    func analyzeNutritionLabel(text: String) async throws -> String {
        try await Task.sleep(for: .seconds(delay))
        try tryShowError()
        return """
        {
          "name": "Protein Shake Mix",
          "measurementMethod": "weight",
          "calories": 380,
          "protein": 30.0,
          "carbs": 45.0,
          "fatTotal": 5.0,
          "fatSaturated": 1.5,
          "fiber": 3.0,
          "sugar": 8.0,
          "sodiumMg": 250,
          "potassiumMg": 420,
          "calciumMg": 200,
          "ironMg": 2.5
        }
        """
    }
}
