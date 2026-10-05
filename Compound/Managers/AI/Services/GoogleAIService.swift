//
//  GoogleAIService.swift
//  Compound
//
//  Created by Andrew Coyle on 28/09/2025.
//

import SwiftUI
import FirebaseFunctions
import FirebaseAuth
import FirebaseAppCheck

struct GoogleAIService: AIService {
    private let functions: Functions
    
    init(functions: Functions = Functions.functions(region: "us-central1")) {
        self.functions = functions
    }
    
    func generateImage(input: String) async throws -> UIImage {
        let payload: [String: Any] = [
            "prompt": input
        ]
        let callable = functions.httpsCallable("imageGenerate")
        let result = try await callable.call(payload)
        guard let dict = result.data as? [String: Any],
              let base64 = dict["base64"] as? String,
              let data = Data(base64Encoded: base64),
              let image = UIImage(data: data) else {
            throw GoogleAIError.invalidResponse
        }
        return image
    }
    
    func analyzeNutritionLabel(text: String) async throws -> String {
        let payload: [String: Any] = ["labelText": text]
        let result = try await functions.httpsCallable("nutritionLabelAnalyze").call(payload)
        guard let dict = result.data as? [String: Any],
              let json = dict["result"] as? String else {
            throw GoogleAIError.invalidResponse
        }
        return json
    }

    func analyzeFood(imageData: Data) async throws -> String {
        let payload: [String: Any] = ["imageBase64": imageData.base64EncodedString()]
        let result = try await functions.httpsCallable("foodAnalyze").call(payload)
        guard let dict = result.data as? [String: Any],
              let json = dict["result"] as? String else {
            throw GoogleAIError.invalidResponse
        }
        return json
    }

    func describeMeal(text: String) async throws -> String {
        let payload: [String: Any] = ["description": text]
        let result = try await functions.httpsCallable("mealDescribe").call(payload)
        guard let dict = result.data as? [String: Any],
              let json = dict["result"] as? String else {
            throw GoogleAIError.invalidResponse
        }
        return json
    }

    enum GoogleAIError: LocalizedError {
        case invalidResponse
    }
}
