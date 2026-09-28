//
//  HealthService.swift
//  DialedIn
//
//  Created by Andrew Coyle on 06/10/2025.
//

#if canImport(HealthKit)
import HealthKit

/// What one feature needs from Apple Health. Each feature asks for its own scope at the moment
/// it is first used, so the permission sheet lists only what that feature reads and writes.
///
/// The single request this replaces asked for about sixty types, most of which nothing read:
/// every dietary type, activity summaries, basal energy, BMI, lean mass, height and waist. Add
/// a type here only together with the code that uses it, and keep the two purpose strings
/// (`NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription`) in step.
enum HealthDataScope: CaseIterable, Sendable {
    /// Starting a workout: saves the workout, reads live heart rate and active energy.
    case workouts
    /// The Steps screen: reads step counts.
    case steps
    /// Logging or viewing weight: reads and writes weight, reads body fat.
    case bodyMeasurements

    var typesToShare: Set<HKSampleType> {
        switch self {
        case .workouts: [HKObjectType.workoutType()]
        case .steps: []
        case .bodyMeasurements: [HKQuantityType(.bodyMass)]
        }
    }

    var typesToRead: Set<HKObjectType> {
        switch self {
        case .workouts: [HKObjectType.workoutType(), HKQuantityType(.activeEnergyBurned), HKQuantityType(.heartRate)]
        case .steps: [HKQuantityType(.stepCount)]
        case .bodyMeasurements: [HKQuantityType(.bodyMass), HKQuantityType(.bodyFatPercentage)]
        }
    }
}

@MainActor
protocol HealthService {
    func canRequestAuthorisation() -> Bool
    func requestAuthorisation(for scope: HealthDataScope) async throws
    func needsAuthorisationForRequiredTypes() -> Bool
    func getHealthStore() -> HKHealthStore
}
#endif
