//
//  ProductionHealthKitWeightService.swift
//  DialedIn
//
//  Created by Andrew Coyle on 29/10/2025.
//
#if canImport(HealthKit)
import HealthKit

struct ProductionHealthKitWeightService: HealthKitWeightService {
    private let healthStore: HKHealthStore

    init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }

    func readWeightSamples(since: Date?) async throws -> [HealthKitWeightSample] {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitWeightServiceError.healthDataUnavailable
        }

        // Safe: a built-in HealthKit quantity identifier always has a type.
        let quantityType = HKQuantityType.quantityType(forIdentifier: .bodyMass)!
        let predicate: NSPredicate?
        if let since {
            predicate = HKQuery.predicateForSamples(withStart: since, end: nil, options: .strictStartDate)
        } else {
            predicate = nil
        }

        return try await withCheckedThrowingContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let unit = HKUnit.gramUnit(with: .kilo)
                let mappedSamples = (samples as? [HKQuantitySample] ?? []).map {
                    HealthKitWeightSample(
                        uuid: $0.uuid,
                        weightKg: $0.quantity.doubleValue(for: unit),
                        date: $0.startDate
                    )
                }
                continuation.resume(returning: mappedSamples)
            }

            healthStore.execute(query)
        }
    }

    func readBodyFatSamples(since: Date?) async throws -> [HealthKitBodyFatSample] {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitWeightServiceError.healthDataUnavailable
        }

        // Safe: a built-in HealthKit quantity identifier always has a type.
        let quantityType = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)!
        let predicate: NSPredicate?
        if let since {
            predicate = HKQuery.predicateForSamples(withStart: since, end: nil, options: .strictStartDate)
        } else {
            predicate = nil
        }

        return try await withCheckedThrowingContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let unit = HKUnit.percent()
                let mappedSamples = (samples as? [HKQuantitySample] ?? []).map {
                    HealthKitBodyFatSample(
                        uuid: $0.uuid,
                        bodyFatPercentage: $0.quantity.doubleValue(for: unit) * 100.0,
                        date: $0.startDate
                    )
                }
                continuation.resume(returning: mappedSamples)
            }

            healthStore.execute(query)
        }
    }

    func saveWeightSample(weightKg: Double, date: Date) async throws -> UUID {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitWeightServiceError.healthDataUnavailable
        }

        // Safe: a built-in HealthKit quantity identifier always has a type.
        let quantityType = HKQuantityType.quantityType(forIdentifier: .bodyMass)!
        let unit = HKUnit.gramUnit(with: .kilo)
        let quantity = HKQuantity(unit: unit, doubleValue: weightKg)
        let sample = HKQuantitySample(type: quantityType, quantity: quantity, start: date, end: date)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.save(sample) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: URLError(.unknown))
                }
            }
        }

        return sample.uuid
    }
}
#endif
