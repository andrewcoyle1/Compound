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

    func readDateOfBirth() -> Date? {
        guard let components = try? healthStore.dateOfBirthComponents() else { return nil }
        return Calendar.current.date(from: components)
    }

    /// `.other` and `.notSet` give nil: neither says which coefficient applies, so the person picks.
    func readSex() -> Gender? {
        switch try? healthStore.biologicalSex().biologicalSex {
        case .male: .male
        case .female: .female
        default: nil
        }
    }

    func readLatestHeightCentimeters() async -> Double? {
        await latestQuantity(.height, unit: .meterUnit(with: .centi))
    }

    func readLatestWeightKilograms() async -> Double? {
        await latestQuantity(.bodyMass, unit: .gramUnit(with: .kilo))
    }

    private func latestQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(identifier))],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1
        )
        return try? await descriptor.result(for: healthStore).first?.quantity.doubleValue(for: unit)
    }
}

#endif
