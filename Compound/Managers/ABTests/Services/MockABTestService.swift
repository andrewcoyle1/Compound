//
//  MockABTestService.swift
//  Compound
//
//  Created by Andrew Coyle on 05/12/2025.
//

import Foundation

@MainActor
class MockABTestService: ABTestService {
    var activeTests: ActiveABTests
    
    init(
        notificationsTest: Bool? = nil,
        paywallTest: PaywallTestOption? = nil
    ) {
        self.activeTests = ActiveABTests(
            notificationsTest: notificationsTest ?? nil,
            paywallTest: paywallTest ?? .default
        )
    }
    
    func saveUpdatedConfig(updatedTests: ActiveABTests) throws {
        activeTests = updatedTests
    }

    func fetchUpdatedConfig() async throws -> ActiveABTests {
        activeTests
    }

}
