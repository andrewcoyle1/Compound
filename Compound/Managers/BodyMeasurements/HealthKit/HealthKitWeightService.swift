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

enum HealthKitWeightServiceError: Error {
    case healthDataUnavailable
}

protocol HealthKitWeightService: Sendable {
    func readWeightSamples(since: Date?) async throws -> [HealthKitWeightSample]
    func readBodyFatSamples(since: Date?) async throws -> [HealthKitBodyFatSample]
    func saveWeightSample(weightKg: Double, date: Date) async throws -> UUID
}
#endif
