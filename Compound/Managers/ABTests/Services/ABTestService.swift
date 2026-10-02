//
//  ABTestService.swift
//  Compound
//
//  Created by Andrew Coyle on 05/12/2025.
//

@MainActor protocol ABTestService: Sendable {
    var activeTests: ActiveABTests { get }
    func saveUpdatedConfig(updatedTests: ActiveABTests) throws
    func fetchUpdatedConfig() async throws -> ActiveABTests
}
