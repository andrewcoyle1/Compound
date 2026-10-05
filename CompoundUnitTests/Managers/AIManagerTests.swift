//
//  AIManagerTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 22/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

/// An `AIService` that records what it was handed and answers with values that cannot be confused
/// for `MockAIService`'s, so a manager that substituted its own input or output would be visible.
private actor AIRecordingService: AIService {
    private(set) var imagePrompts: [String] = []
    private(set) var foodImageData: [Data] = []
    private(set) var labelText: [String] = []
    private(set) var mealText: [String] = []

    func generateImage(input: String) async throws -> UIImage {
        imagePrompts.append(input)
        return UIImage(systemName: "bolt.fill")!
    }

    func analyzeFood(imageData: Data) async throws -> String {
        foodImageData.append(imageData)
        return "food"
    }

    func analyzeNutritionLabel(text: String) async throws -> String {
        labelText.append(text)
        return "label"
    }

    func describeMeal(text: String) async throws -> String {
        mealText.append(text)
        return "meal"
    }
}

/// The single door between the app and the AI callables.
///
/// The manager holds no state and transforms nothing — which is exactly what these tests pin.
/// Every call is forwarded verbatim and every failure is rethrown, because each caller decides for
/// itself what a failed analysis means: the food scanner offers a retry, the chat shows an error
/// bubble. A manager that swallowed an error, or that trimmed an input on the way past, would
/// leave those callers showing an empty result instead.
///
/// `GoogleAIService` is not covered here — it calls Firebase `Functions.functions()` directly, so
/// nothing about the wire format can be reached from this target. `MockAIService` is the payload
/// contract the food and label parsers are written against, so the shape of what it returns is
/// asserted below.
@MainActor
struct AIManagerTests {

    private func jsonObject(_ string: String) throws -> [String: Any] {
        let data = try #require(string.data(using: .utf8))
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: - Forwarding

    /// Everything the user gave has to reach the service unchanged.
    @Test("Test Every Call Reaches The Service With Its Input Untouched")
    func testEveryCallReachesTheServiceUntouched() async throws {
        let service = AIRecordingService()
        let manager = AIManager(service: service)
        let imageData = Data([0x01, 0x02, 0x03])

        _ = try await manager.generateImage(input: "a plate of oats")
        _ = try await manager.analyzeFood(imageData: imageData)
        _ = try await manager.analyzeNutritionLabel(text: "Calories 380")
        _ = try await manager.describeMeal(text: "two eggs and toast")

        let prompts = await service.imagePrompts
        let food = await service.foodImageData
        let label = await service.labelText
        let meal = await service.mealText

        #expect(prompts == ["a plate of oats"])
        #expect(food == [imageData])
        #expect(label == ["Calories 380"])
        #expect(meal == ["two eggs and toast"])
    }

    @Test("Test The Service's Answer Is Returned Verbatim")
    func testTheServicesAnswerIsReturnedVerbatim() async throws {
        let manager = AIManager(service: AIRecordingService())

        let food = try await manager.analyzeFood(imageData: Data())
        let label = try await manager.analyzeNutritionLabel(text: "")
        let meal = try await manager.describeMeal(text: "")

        #expect(food == "food")
        #expect(label == "label")
        #expect(meal == "meal")
    }

    // MARK: - Mocked payloads

    @Test("Test Generated Images Come Back With Real Dimensions")
    func testGeneratedImagesComeBackWithRealDimensions() async throws {
        let manager = AIManager(service: MockAIService())

        let image = try await manager.generateImage(input: "a plate of oats")

        #expect(image.size.width > 0)
        #expect(image.size.height > 0)
    }

    /// The food scanner parses this string into meal items, so the mock has to keep answering
    /// something that parses — a mocked scan is the only way that screen is exercised without a
    /// Firebase project.
    @Test("Test The Mocked Food Analysis Parses Into Items")
    func testMockedFoodAnalysisParsesIntoItems() async throws {
        let manager = AIManager(service: MockAIService())

        let json = try jsonObject(try await manager.analyzeFood(imageData: Data()))
        let items = try #require(json["items"] as? [[String: Any]])

        #expect(items.count == 3)
        #expect(items.first?["name"] as? String == "Grilled Chicken Breast")
        #expect(items.allSatisfy { $0["calories"] != nil && $0["proteinGrams"] != nil })
    }

    @Test("Test The Mocked Meal Description Parses Into Items")
    func testMockedMealDescriptionParsesIntoItems() async throws {
        let manager = AIManager(service: MockAIService())

        let json = try jsonObject(try await manager.describeMeal(text: "chicken and rice"))
        let items = try #require(json["items"] as? [[String: Any]])

        #expect(items.count == 3)
    }

    /// A label scan answers a single food, not a list — the parser behind it reads the macros off
    /// the top level rather than out of `items`.
    @Test("Test The Mocked Label Analysis Is One Food With Macros")
    func testMockedLabelAnalysisIsOneFoodWithMacros() async throws {
        let manager = AIManager(service: MockAIService())

        let json = try jsonObject(try await manager.analyzeNutritionLabel(text: "Calories 380"))

        #expect(json["name"] as? String == "Protein Shake Mix")
        #expect(json["calories"] as? Int == 380)
        #expect(json["protein"] as? Double == 30.0)
        #expect(json["items"] == nil)
    }

    // MARK: - Errors

    /// Each caller shows its own failure state, so the manager must not turn a failure into an
    /// empty success — a silently empty analysis reads as "this food has no calories".
    @Test("Test Every Call Rethrows The Service's Error")
    func testEveryCallRethrowsTheServicesError() async {
        let manager = AIManager(service: MockAIService(showError: true))

        await #expect(throws: (any Error).self) { _ = try await manager.generateImage(input: "x") }
        await #expect(throws: (any Error).self) { _ = try await manager.analyzeFood(imageData: Data()) }
        await #expect(throws: (any Error).self) { _ = try await manager.analyzeNutritionLabel(text: "x") }
        await #expect(throws: (any Error).self) { _ = try await manager.describeMeal(text: "x") }
    }

    /// The error is passed through rather than wrapped, so a caller that branches on a specific
    /// failure — an offline `URLError`, say — still can.
    @Test("Test The Thrown Error Is The Service's Own")
    func testTheThrownErrorIsTheServicesOwn() async {
        let manager = AIManager(service: MockAIService(showError: true))

        await #expect(throws: URLError.self) { _ = try await manager.analyzeFood(imageData: Data()) }
    }
}
