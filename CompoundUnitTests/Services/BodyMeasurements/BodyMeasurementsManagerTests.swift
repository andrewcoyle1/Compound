//
//  BodyMeasurementsManagerTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 20/09/2026.
//

import Testing
import Foundation
@testable import Compound

/// Saving and removing body measurements.
///
/// What the app holds, what it does when an entry is added or removed, and the Apple Health weight
/// import against a mock Health store.
@MainActor
struct BodyMeasurementsManagerTests {

    private func entry(id: String, weightKg: Double?, daysAgo: Int = 0) -> BodyMeasurementEntry {
        let date = Date(timeIntervalSince1970: 1_000_000).addingTimeInterval(Double(-daysAgo) * 86400)
        return BodyMeasurementEntry(
            id: id,
            authorId: "author-1",
            weightKg: weightKg,
            date: date,
            source: .manual,
            dateCreated: date
        )
    }

    private var threeWeighIns: [BodyMeasurementEntry] {
        [
            entry(id: "e1", weightKg: 73.0, daysAgo: 2),
            entry(id: "e2", weightKg: 72.6, daysAgo: 1),
            entry(id: "e3", weightKg: 72.4)
        ]
    }

    @Test("Test Measurements Are Empty Until Signed In")
    func testMeasurementsAreEmptyUntilSignedIn() {
        #expect(TestManagers.bodyMeasurementsManager(entries: threeWeighIns).bodyMeasurements.isEmpty)
    }

    @Test("Test Signing In Loads The Measurements")
    func testSigningInLoadsTheMeasurements() async {
        let manager = await TestManagers.signedInBodyMeasurementsManager(entries: threeWeighIns)

        #expect(manager.bodyMeasurements.count == 3)
    }

    @Test("Test Saving A Measurement Adds It")
    func testSavingAMeasurementAddsIt() async throws {
        let manager = await TestManagers.signedInBodyMeasurementsManager(entries: [])

        try await manager.saveBodyMeasurement(bodyMeasurement: entry(id: "new", weightKg: 72.0))

        let added = await TestManagers.eventually { manager.bodyMeasurements.map(\.id) == ["new"] }
        #expect(added)
    }

    /// Saving under an existing id corrects that weigh-in rather than logging a second one for the
    /// same moment.
    @Test("Test Saving Over A Measurement Replaces It")
    func testSavingOverAMeasurementReplacesIt() async throws {
        let manager = await TestManagers.signedInBodyMeasurementsManager(entries: threeWeighIns)

        try await manager.saveBodyMeasurement(bodyMeasurement: entry(id: "e3", weightKg: 71.9))

        let replaced = await TestManagers.eventually {
            manager.bodyMeasurements.first { $0.id == "e3" }?.weightKg == 71.9
        }
        #expect(replaced)
        #expect(manager.bodyMeasurements.count == 3)
    }

    /// An entry can record a circumference and no weight, so the collection must hold it either way.
    @Test("Test A Measurement Without A Weight Is Still Kept")
    func testAMeasurementWithoutAWeightIsStillKept() async throws {
        let manager = await TestManagers.signedInBodyMeasurementsManager(entries: [])
        let waistOnly = entry(id: "waist", weightKg: nil).withUpdated(.waist(81))

        try await manager.saveBodyMeasurement(bodyMeasurement: waistOnly)

        let added = await TestManagers.eventually { manager.bodyMeasurements.count == 1 }
        #expect(added)
        #expect(manager.bodyMeasurements.first?.weightKg == nil)
        #expect(manager.bodyMeasurements.first?.waistCircumference == 81)
    }

    @Test("Test Deleting A Measurement Removes It")
    func testDeletingAMeasurementRemovesIt() async throws {
        let manager = await TestManagers.signedInBodyMeasurementsManager(entries: threeWeighIns)

        try await manager.deleteWeightEntry(entryId: "e2")

        let removed = await TestManagers.eventually { manager.bodyMeasurements.count == 2 }
        #expect(removed)
        #expect(!manager.bodyMeasurements.map(\.id).contains("e2"))
    }

    // MARK: Apple Health import

    private static let healthDay = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_000_000))

    private func weighIn(_ weightKg: Double, hour: Double) -> HealthKitWeightSample {
        HealthKitWeightSample(uuid: UUID(), weightKg: weightKg, date: Self.healthDay.addingTimeInterval(hour * 3600))
    }

    /// The import's anchor is kept in UserDefaults per user, and tests run in parallel, so each
    /// signs in as a user of its own.
    private func signedInWithHealth(
        _ health: MockHealthKitWeightService,
        userId: String = UUID().uuidString,
        entries: [BodyMeasurementEntry] = []
    ) async -> BodyMeasurementsManager {
        let manager = TestManagers.bodyMeasurementsManager(entries: entries, healthKitService: health)
        await manager.signIn(userId: userId)
        return manager
    }

    /// One entry per day, at its lowest weigh-in, carrying that day's latest body fat.
    @Test("Test Signing In Imports Apple Health One Entry Per Day")
    func testSigningInImportsAppleHealthOneEntryPerDay() async {
        let health = MockHealthKitWeightService(
            samples: [weighIn(72.8, hour: 8), weighIn(72.5, hour: 20), weighIn(72.1, hour: 32)],
            bodyFatSamples: [HealthKitBodyFatSample(uuid: UUID(), bodyFatPercentage: 18.2, date: Self.healthDay.addingTimeInterval(8 * 3600))]
        )
        let manager = await signedInWithHealth(health)

        let imported = await TestManagers.eventually { manager.bodyMeasurements.count == 2 }
        #expect(imported)
        let firstDay = manager.bodyMeasurements.first { $0.weightKg == 72.5 }
        #expect(firstDay?.bodyFatPercentage == 18.2)
        #expect(Set(manager.bodyMeasurements.compactMap(\.weightKg)) == [72.5, 72.1])
        #expect(manager.bodyMeasurements.allSatisfy { $0.source == .healthkit })
    }

    /// A lower reading later the same day replaces that day's entry rather than adding a second.
    @Test("Test A Lower Reading In Apple Health Updates The Day")
    func testALowerReadingInAppleHealthUpdatesTheDay() async {
        let health = MockHealthKitWeightService(samples: [weighIn(72.8, hour: 8)])
        let manager = await signedInWithHealth(health)
        _ = await TestManagers.eventually { manager.bodyMeasurements.count == 1 }

        health.add(weighIn(72.4, hour: 20))

        let updated = await TestManagers.eventually { manager.bodyMeasurements.first?.weightKg == 72.4 }
        #expect(updated)
        #expect(manager.bodyMeasurements.count == 1)
    }

    /// Deleting the day's only weigh-in in Apple Health clears it here too.
    @Test("Test Deleting In Apple Health Clears The Weight")
    func testDeletingInAppleHealthClearsTheWeight() async {
        let sample = weighIn(72.8, hour: 8)
        let health = MockHealthKitWeightService(samples: [sample])
        let manager = await signedInWithHealth(health)
        _ = await TestManagers.eventually { manager.bodyMeasurements.first?.weightKg == 72.8 }

        health.delete(sample.uuid)

        let cleared = await TestManagers.eventually { manager.bodyMeasurements.first?.weightKg == nil }
        #expect(cleared)
    }

    /// A weigh-in already logged in the app that day, as low or lower, is not doubled up.
    @Test("Test A Lower Weigh-In Logged Here Wins The Day")
    func testALowerWeighInLoggedHereWinsTheDay() async {
        let userId = UUID().uuidString
        let logged = BodyMeasurementEntry(id: "manual", authorId: userId, weightKg: 72.0, date: Self.healthDay, source: .manual)
        let health = MockHealthKitWeightService(samples: [weighIn(72.8, hour: 8)])
        let manager = await signedInWithHealth(health, userId: userId, entries: [logged])
        _ = await TestManagers.eventually { manager.bodyMeasurements.count == 1 }

        health.add(weighIn(72.6, hour: 20))
        let doubled = await TestManagers.eventually(timeout: .milliseconds(500)) { manager.bodyMeasurements.count > 1 }

        #expect(!doubled)
    }
}
