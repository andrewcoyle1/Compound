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

    // Onboarding's "Fill from Apple Health": ask for the one type the step needs, at the moment
    // the person taps, then read it. Any failure, including a refusal, comes back as nil so the
    // step can say nothing was found and leave manual entry as it is.

    func readDateOfBirth() async -> Date? {
        guard await requestIfPossible(.dateOfBirth) else { return nil }
        return service.readDateOfBirth()
    }

    func readSex() async -> Gender? {
        guard await requestIfPossible(.sex) else { return nil }
        return service.readSex()
    }

    func readLatestHeightCentimeters() async -> Double? {
        guard await requestIfPossible(.height) else { return nil }
        return await service.readLatestHeightCentimeters()
    }

    func readLatestWeightKilograms() async -> Double? {
        guard await requestIfPossible(.weight) else { return nil }
        return await service.readLatestWeightKilograms()
    }

    private func requestIfPossible(_ scope: HealthDataScope) async -> Bool {
        guard service.canRequestAuthorisation() else { return false }
        return (try? await service.requestAuthorisation(for: scope)) != nil
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

    func readDateOfBirthFromAppleHealth() async -> Date? {
        await healthKitManager.readDateOfBirth()
    }

    func readSexFromAppleHealth() async -> Gender? {
        await healthKitManager.readSex()
    }

    func readHeightCentimetersFromAppleHealth() async -> Double? {
        await healthKitManager.readLatestHeightCentimeters()
    }

    func readWeightKilogramsFromAppleHealth() async -> Double? {
        await healthKitManager.readLatestWeightKilograms()
    }

}
#endif
