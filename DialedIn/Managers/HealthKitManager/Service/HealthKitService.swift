//
//  HealthKitService.swift
//  DialedIn
//
//  Created by Andrew Coyle on 06/10/2025.
//

#if canImport(HealthKit)
import HealthKit

struct HealthKitService: HealthService {

    let healthStore: HKHealthStore = HKHealthStore()

    func canRequestAuthorisation() -> Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorisation(for scope: HealthDataScope) async throws {
        guard canRequestAuthorisation() else {
            throw NSError(domain: "HealthKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "Health data not available on this device"])
        }

        try await healthStore.requestAuthorization(toShare: scope.typesToShare, read: scope.typesToRead)
    }

    func needsAuthorisationForRequiredTypes() -> Bool {
        guard canRequestAuthorisation() else { return false }

        // Require workout sharing authorization to start HKWorkoutSession
        let workoutType = HKObjectType.workoutType()
        let status = healthStore.authorizationStatus(for: workoutType)
        switch status {
        case .sharingAuthorized:
            return false
        case .notDetermined, .sharingDenied:
            return true
        @unknown default:
            return true
        }
    }

    func getHealthStore() -> HKHealthStore {
        healthStore
    }
}

#endif
