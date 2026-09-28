//
//  HealthKitManager.swift
//  DialedIn
//
//  Created by Andrew Coyle on 02/10/2025.
//

import Foundation
import SwiftUI

#if canImport(HealthKit)
import HealthKit

@Observable
@MainActor
class HealthKitManager {
    
    private let service: HealthService
    let healthStore: HKHealthStore
    var isAuthorized: Bool
    
    init(service: HealthService = HealthKitService()) {
        self.service = service
        self.healthStore = service.getHealthStore()
        self.isAuthorized = false
    }
    
    func canRequestAuthorisation() -> Bool {
        service.canRequestAuthorisation()
    }
    
    func requestAuthorisation(for scope: HealthDataScope) async throws {
        try await service.requestAuthorisation(for: scope)
    }
    
    /// Returns true when we should present the HealthKit permissions screen
    /// for our required types (represents whether user has not yet granted or has denied access).
    /// Uses `HKQuantityType(.bodyMass)` as the representative write-permission type
    /// since read authorization status cannot be queried.
    func needsAuthorisationForRequiredTypes() -> Bool {
        service.needsAuthorisationForRequiredTypes()
    }
    
    func getHealthStore() -> HKHealthStore {
        service.getHealthStore()
    }
}

extension CoreInteractor {
    // HealthKitManager
    var healthKitIsAuthorized: Bool {
        healthKitManager.isAuthorized
    }
    
    func canRequestHealthDataAuthorisation() -> Bool {
        healthKitManager.canRequestAuthorisation()
    }
    
    func requestHealthKitAuthorisation(for scope: HealthDataScope) async throws {
        try await healthKitManager.requestAuthorisation(for: scope)
    }
    
    func needsAuthorisationForRequiredTypes() -> Bool {
        healthKitManager.needsAuthorisationForRequiredTypes()
    }
    
    func getHealthStore() -> HKHealthStore {
        healthKitManager.getHealthStore()
    }

}
#endif
