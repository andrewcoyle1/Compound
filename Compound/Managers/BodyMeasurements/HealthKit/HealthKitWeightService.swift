//
//  HealthKitWeightService.swift
//  Compound
//
//  Created by Andrew Coyle on 29/10/2025.
//
#if canImport(HealthKit)
import HealthKit

struct HealthKitWeightSample: Equatable {
    let uuid: UUID
    let weightKg: Double
    let date: Date
}

struct HealthKitBodyFatSample: Equatable {
    let uuid: UUID
    let bodyFatPercentage: Double
    let date: Date
}

/// What changed in Apple Health's weight and body fat since `anchor` was handed out. Deleted
/// samples carry no date in HealthKit, only their UUID.
struct HealthKitBodyChanges: Sendable {
    var addedDates: [Date]
    var deletedUUIDs: Set<UUID>
    /// Opaque; pass back to `changes(after:)` to get only what changed since this call.
    var anchor: Data?
}

enum HealthKitWeightServiceError: Error {
    case healthDataUnavailable
}

/// Every read leaves out samples this app wrote: those are weigh-ins logged here, which already
/// have an entry.
@MainActor
protocol HealthKitWeightService: Sendable {
    func changes(after anchor: Data?) async throws -> HealthKitBodyChanges
    func readWeightSamples(from start: Date, to end: Date) async throws -> [HealthKitWeightSample]
    func readBodyFatSamples(from start: Date, to end: Date) async throws -> [HealthKitBodyFatSample]
    /// Fires when weight or body fat may have changed in Apple Health. Ends when cancelled.
    func changeNotifications() -> AsyncStream<Void>
    func saveWeightSample(weightKg: Double, date: Date) async throws -> UUID
}
#endif
