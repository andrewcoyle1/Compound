//
//  ProductionHealthKitWeightService.swift
//  Compound
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

    private nonisolated static let bodyMass = HKQuantityType(.bodyMass)
    private nonisolated static let bodyFat = HKQuantityType(.bodyFatPercentage)

    @concurrent
    nonisolated func changes(after anchor: Data?) async throws -> HealthKitBodyChanges {
        try checkAvailable()
        let descriptor = HKAnchoredObjectQueryDescriptor(
            predicates: [
                .quantitySample(type: Self.bodyMass, predicate: HKHealthStore.notFromThisApp),
                .quantitySample(type: Self.bodyFat, predicate: HKHealthStore.notFromThisApp)
            ],
            anchor: HKHealthStore.anchor(from: anchor)
        )
        let result = try await descriptor.result(for: healthStore)
        return HealthKitBodyChanges(
            addedDates: result.addedSamples.map(\.startDate),
            deletedUUIDs: Set(result.deletedObjects.map(\.uuid)),
            anchor: HKHealthStore.data(from: result.newAnchor)
        )
    }

    @concurrent
    nonisolated func readWeightSamples(from start: Date, to end: Date) async throws -> [HealthKitWeightSample] {
        try await samples(Self.bodyMass, from: start, to: end).map {
            HealthKitWeightSample(uuid: $0.uuid, weightKg: $0.quantity.doubleValue(for: .gramUnit(with: .kilo)), date: $0.startDate)
        }
    }

    @concurrent
    nonisolated func readBodyFatSamples(from start: Date, to end: Date) async throws -> [HealthKitBodyFatSample] {
        try await samples(Self.bodyFat, from: start, to: end).map {
            HealthKitBodyFatSample(uuid: $0.uuid, bodyFatPercentage: $0.quantity.doubleValue(for: .percent()) * 100.0, date: $0.startDate)
        }
    }

    @concurrent
    private nonisolated func samples(_ type: HKQuantityType, from start: Date, to end: Date) async throws -> [HKQuantitySample] {
        try checkAvailable()
        let inRange = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type, predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [inRange, HKHealthStore.notFromThisApp]))],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        return try await descriptor.result(for: healthStore)
    }

    func changeNotifications() -> AsyncStream<Void> {
        healthStore.changeNotifications(for: [Self.bodyMass, Self.bodyFat])
    }

    @concurrent
    nonisolated func saveWeightSample(weightKg: Double, date: Date) async throws -> UUID {
        try checkAvailable()
        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: weightKg)
        let sample = HKQuantitySample(type: Self.bodyMass, quantity: quantity, start: date, end: date)
        try await healthStore.save(sample)
        return sample.uuid
    }

    private nonisolated func checkAvailable() throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitWeightServiceError.healthDataUnavailable
        }
    }
}
#endif
