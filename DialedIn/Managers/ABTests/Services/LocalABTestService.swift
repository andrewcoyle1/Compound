//
//  LocalABTestService.swift
//  DialedIn
//
//  Created by Andrew Coyle on 05/12/2025.
//

@MainActor
class LocalABTestService: ABTestService {
    @UserDefault(key: ActiveABTests.CodingKeys.notificationsTest.rawValue, startingValue: .random())
    private var notificationsTest: Bool
    
    // Safe: PaywallTestOption.allCases is non-empty.
    @UserDefaultEnum(key: ActiveABTests.CodingKeys.paywallTest.rawValue, startingValue: PaywallTestOption.allCases.randomElement()!)
    private var paywallTest: PaywallTestOption

    var activeTests: ActiveABTests {
        ActiveABTests(
            notificationsTest: notificationsTest,
            paywallTest: paywallTest
        )
    }
    
    func saveUpdatedConfig(updatedTests: ActiveABTests) throws {
        
        // Every new test need to be added here to ensure that it can be updated
        notificationsTest = updatedTests.notificationsTest
        paywallTest = updatedTests.paywallTest
    }
    
    func fetchUpdatedConfig() async throws -> ActiveABTests {
        activeTests
    }
}
