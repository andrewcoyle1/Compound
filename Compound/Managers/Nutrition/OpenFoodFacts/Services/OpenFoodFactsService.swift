//
//  OpenFoodFactsService 2.swift
//  Compound
//
//  Created by Andrew Coyle on 12/03/2026.
//

@MainActor
protocol OpenFoodFactsService {
    func lookupBarcode(_ code: String) async throws -> FoodModel
    func searchFoods(query: String) async throws -> [FoodModel]
}
