//
//  BodyMeasurementsManagerTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 20/09/2026.
//

import Testing
import Foundation
@testable import DialedIn

/// Saving and removing body measurements.
///
/// The HealthKit sync and backfill on this manager need the real framework, so what is covered here
/// is the part that runs whether or not Health is connected: what the app holds, and what it does
/// when an entry is added or removed.
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
}
