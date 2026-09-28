//
//  MockHealthService.swift
//  DialedIn
//
//  Created by Andrew Coyle on 06/10/2025.
//

#if canImport(HealthKit)
import HealthKit

struct MockHealthService: HealthService {
    
    let delay: Double
    let showError: Bool
    let canRequestAuthorisationTest: Bool
    
    init(delay: Double = 0.0, showError: Bool = false, canRequestAuthorisation: Bool = true) {
        self.delay = delay
        self.showError = showError
        self.canRequestAuthorisationTest = canRequestAuthorisation
    }
    
    private func tryShowError() throws {
        if showError {
            throw URLError(.unknown)
        }
    }
    
    func canRequestAuthorisation() -> Bool {
        canRequestAuthorisationTest
    }
    
    func requestAuthorisation(for scope: HealthDataScope) async throws {
        try await Task.sleep(for: .seconds(delay))
        try tryShowError()
    }
    
    func needsAuthorisationForRequiredTypes() -> Bool {
        true
    }
    
    func getHealthStore() -> HKHealthStore {
        HKHealthStore()
    }
}
#endif
