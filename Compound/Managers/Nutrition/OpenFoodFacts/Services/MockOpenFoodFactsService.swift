//
//  MockOpenFoodFactsService.swift
//  Compound
//
//  Created by Andrew Coyle on 12/03/2026.
//

import Foundation

final class MockOpenFoodFactsService: OpenFoodFactsService {
    func lookupBarcode(_ code: String) async throws -> FoodModel {
        try await Task.sleep(nanoseconds: 500_000_000)
        return FoodModel.mocks[0]
    }

    func searchFoods(query: String) async throws -> [FoodModel] {
        try await Task.sleep(nanoseconds: 500_000_000)
        return FoodModel.mocks
    }
}
