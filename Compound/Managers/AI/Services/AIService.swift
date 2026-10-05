//
//  AIService.swift
//  Compound
//
//  Created by Andrew Coyle on 10/15/24.
//
import SwiftUI

protocol AIService: Sendable {
    func generateImage(input: String) async throws -> UIImage
    func analyzeFood(imageData: Data) async throws -> String
    func analyzeNutritionLabel(text: String) async throws -> String
    func describeMeal(text: String) async throws -> String
}
