//
//  HealthKitManagerTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 22/09/2026.
//

import Testing
import Foundation
@testable import Compound

#if canImport(HealthKit) && !targetEnvironment(macCatalyst)
import HealthKit

/// `HealthKitManager` is a thin pass-through to `HealthService`, so these pin the two things it
/// actually does on top of the service: start `isAuthorized` false regardless of what the service
/// would report, and propagate a `requestAuthorisation()` failure rather than swallowing it.
@MainActor
struct HealthKitManagerTests {

    @Test("Test A New Manager Is Not Authorized Even When The Service Can Request It")
    func testANewManagerIsNotAuthorizedEvenWhenTheServiceCanRequestIt() {
        let manager = HealthKitManager(service: MockHealthService(canRequestAuthorisation: true))

        #expect(manager.isAuthorized == false)
    }

    @Test("Test Can Request Authorisation Reflects The Service")
    func testCanRequestAuthorisationReflectsTheService() {
        #expect(HealthKitManager(service: MockHealthService(canRequestAuthorisation: true)).canRequestAuthorisation())
        #expect(HealthKitManager(service: MockHealthService(canRequestAuthorisation: false)).canRequestAuthorisation() == false)
    }

    @Test("Test Requesting Authorisation Succeeds When The Service Does")
    func testRequestingAuthorisationSucceedsWhenTheServiceDoes() async throws {
        let manager = HealthKitManager(service: MockHealthService(showError: false))

        try await manager.requestAuthorisation(for: .workouts)
    }

    @Test("Test Requesting Authorisation Propagates The Service's Failure")
    func testRequestingAuthorisationPropagatesTheServicesFailure() async {
        let manager = HealthKitManager(service: MockHealthService(showError: true))

        await #expect(throws: (any Error).self) {
            try await manager.requestAuthorisation(for: .workouts)
        }
    }

    @Test("Test Needs Authorisation For Required Types Reflects The Service")
    func testNeedsAuthorisationForRequiredTypesReflectsTheService() {
        let manager = HealthKitManager(service: MockHealthService())

        #expect(manager.needsAuthorisationForRequiredTypes())
    }

    @Test("Test Get Health Store Routes Through The Service Rather Than A Stored Constant")
    func testGetHealthStoreRoutesThroughTheServiceRatherThanAStoredConstant() {
        // `MockHealthService.getHealthStore()` hands back a fresh `HKHealthStore` on every call.
        // If `HealthKitManager.getHealthStore()` returned its own cached `healthStore` instead of
        // calling through, this would still pass — the point is that it doesn't crash routing to
        // the service on every call, matching what `init` did to populate `healthStore` itself.
        let manager = HealthKitManager(service: MockHealthService())

        let first = manager.getHealthStore()
        let second = manager.getHealthStore()

        #expect(type(of: first) == HKHealthStore.self)
        #expect(type(of: second) == HKHealthStore.self)
    }

    // The onboarding screen promised "weight" while one request asked for about sixty types,
    // most of them never read. These pin each feature's request to what it uses.

    @Test("Test Each Scope Asks Only For What Its Feature Uses")
    func testEachScopeAsksOnlyForWhatItsFeatureUses() {
        #expect(HealthDataScope.workouts.typesToShare == [HKObjectType.workoutType(), HKQuantityType(.activeEnergyBurned), HKQuantityType(.heartRate)])
        #expect(HealthDataScope.workouts.typesToRead == [HKObjectType.workoutType(), HKQuantityType(.activeEnergyBurned), HKQuantityType(.heartRate)])
        #expect(HealthDataScope.steps.typesToShare.isEmpty)
        #expect(HealthDataScope.steps.typesToRead == [HKQuantityType(.stepCount)])
        #expect(HealthDataScope.nutrition.typesToShare.isEmpty)
        #expect(HealthDataScope.bodyMeasurements.typesToShare == [HKQuantityType(.bodyMass)])
        #expect(HealthDataScope.bodyMeasurements.typesToRead == [HKQuantityType(.bodyMass), HKQuantityType(.bodyFatPercentage)])
        // Onboarding's "Fill from Apple Health" buttons read one type each and write nothing.
        #expect(HealthDataScope.dateOfBirth.typesToRead == [HKCharacteristicType(.dateOfBirth)])
        #expect(HealthDataScope.sex.typesToRead == [HKCharacteristicType(.biologicalSex)])
        #expect(HealthDataScope.height.typesToRead == [HKQuantityType(.height)])
        #expect(HealthDataScope.weight.typesToRead == [HKQuantityType(.bodyMass)])
        for scope in [HealthDataScope.dateOfBirth, .sex, .height, .weight] {
            #expect(scope.typesToShare.isEmpty)
        }
    }

    @Test("Test Each Onboarding Read Returns What Apple Health Holds")
    func testEachOnboardingReadReturnsWhatAppleHealthHolds() async {
        var service = MockHealthService()
        let birth = Date(timeIntervalSince1970: 0)
        service.dateOfBirth = birth
        service.sex = .female
        service.heightCentimeters = 170
        service.weightKilograms = 65
        let manager = HealthKitManager(service: service)

        #expect(await manager.readDateOfBirth() == birth)
        #expect(await manager.readSex() == .female)
        #expect(await manager.readLatestHeightCentimeters() == 170)
        #expect(await manager.readLatestWeightKilograms() == 65)
    }

    /// A refused or failed request is not an error on screen: the step says nothing was found and
    /// manual entry carries on.
    @Test("Test Onboarding Reads Return Nothing When Access Cannot Be Requested Or Fails")
    func testOnboardingReadsReturnNothingWhenAccessFails() async {
        var failing = MockHealthService(showError: true)
        failing.weightKilograms = 65
        #expect(await HealthKitManager(service: failing).readLatestWeightKilograms() == nil)

        var unavailable = MockHealthService(canRequestAuthorisation: false)
        unavailable.sex = .male
        #expect(await HealthKitManager(service: unavailable).readSex() == nil)
    }

    /// Only the daily energy and macro totals the import stores, not every dietary type.
    @Test("Test Only The Nutrition Scope Reads Dietary Data, And Only Energy And Macros")
    func testOnlyTheNutritionScopeReadsDietaryData() {
        #expect(HealthDataScope.nutrition.typesToRead == [
            HKQuantityType(.dietaryEnergyConsumed), HKQuantityType(.dietaryProtein),
            HKQuantityType(.dietaryCarbohydrates), HKQuantityType(.dietaryFatTotal)
        ])
        for scope in HealthDataScope.allCases where scope != .nutrition {
            let requested = scope.typesToRead.map(\.identifier) + scope.typesToShare.map(\.identifier)
            #expect(!requested.contains { $0.contains("Dietary") })
        }
    }
}

#endif
