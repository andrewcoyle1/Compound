//
//  AIManager.swift
//  Compound
//
//  Created by Andrew Coyle on 10/15/24.
//
import SwiftUI

@Observable
@MainActor
class AIManager {
    
    private let service: AIService
    
    init(service: AIService) {
        self.service = service
    }
    
    func generateImage(input: String) async throws -> UIImage {
        try await service.generateImage(input: input)
    }
    
    func analyzeFood(imageData: Data) async throws -> String {
        try await service.analyzeFood(imageData: imageData)
    }

    func analyzeNutritionLabel(text: String) async throws -> String {
        try await service.analyzeNutritionLabel(text: text)
    }

    func describeMeal(text: String) async throws -> String {
        try await service.describeMeal(text: text)
    }
}

extension CoreInteractor {
    // MARK: AIManager

    func generateImage(input: String) async throws -> UIImage {
        try await aiManager.generateImage(input: input)
    }

    func analyzeFood(imageData: Data) async throws -> String {
        try await aiManager.analyzeFood(imageData: imageData)
    }

    func analyzeNutritionLabel(text: String) async throws -> String {
        try await aiManager.analyzeNutritionLabel(text: text)
    }

    func describeMeal(text: String) async throws -> String {
        try await aiManager.describeMeal(text: text)
    }

}
