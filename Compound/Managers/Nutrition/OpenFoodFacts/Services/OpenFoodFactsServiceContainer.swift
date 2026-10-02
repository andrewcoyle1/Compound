//
//  OpenFoodFactsServiceContainer.swift
//  Compound
//
//  Created by Andrew Coyle on 12/03/2026.
//

@MainActor
final class OpenFoodFactsServiceContainer {
    let service: any OpenFoodFactsService
    init(_ service: any OpenFoodFactsService) { self.service = service }
}
