//
//  StepsManagerTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 22/09/2026.
//

import Testing
import Foundation
@testable import Compound

#if canImport(HealthKit)

/// `StepsManager`'s HealthKit import: which samples get pulled in, which are skipped as
/// duplicates, and how the local steps history holds up as the source of truth.
///
/// `importFromHealthKit` reads `UserDefaults.standard` for its "last synced" watermark under a
/// fixed key, so every test that exercises it clears that key first and again afterwards —
/// otherwise a run order where one test's sync date lingers would make a later test's samples
/// look already-imported. Serialized for the same reason two tests must never race that key.
@Suite(.serialized)
@MainActor
struct StepsManagerTests {

    private static let syncDateKey = "healthkit.steps.lastSyncDate"

    private func resetSyncWatermark() {
        UserDefaults.standard.removeObject(forKey: Self.syncDateKey)
    }

    private func entry(number: Int, date: Date, authorId: String = "author-1", healthKitId: String? = nil, deletedAt: Date? = nil) -> StepsModel {
        StepsModel(authorId: authorId, number: number, date: date, deletedAt: deletedAt, healthKitId: healthKitId)
    }

    // MARK: - Signing In

    @Test("Test Steps History Is Empty Until Signed In")
    func testStepsHistoryIsEmptyUntilSignedIn() {
        #expect(TestManagers.stepsManager(entries: [entry(number: 1_000, date: .now)]).stepsHistory.isEmpty)
    }

    @Test("Test Creating An Entry Saves It To The Sync Engine")
    func testCreatingAnEntrySavesItToTheSyncEngine() async {
        let manager = await TestManagers.signedInStepsManager()
        let newEntry = entry(number: 5_000, date: .now)

        try? await manager.createStepsEntry(steps: newEntry)

        #expect(await TestManagers.eventually { manager.stepsHistory.contains { $0.id == newEntry.id } })
    }

    // MARK: - Backfill: only when local history is empty

    @Test("Test Backfill Does Nothing When Local History Is Not Empty")
    func testBackfillDoesNothingWhenLocalHistoryIsNotEmpty() async {
        resetSyncWatermark()
        defer { resetSyncWatermark() }

        let existing = entry(number: 4_000, date: .now)
        let healthKit = MockHealthKitStepsService(samples: [
            HealthKitStepsSample(id: "sample-1", steps: 7_000, date: .now)
        ])
        let manager = await TestManagers.signedInStepsManager(entries: [existing], healthKitService: healthKit)

        await manager.backfillStepsFromHealthKit(userId: "author-1")

        #expect(manager.stepsHistory.count == 1)
        #expect(manager.stepsHistory.first?.id == existing.id)
    }

    @Test("Test Backfill Imports Every Sample When Local History Is Empty")
    func testBackfillImportsEverySampleWhenLocalHistoryIsEmpty() async {
        resetSyncWatermark()
        defer { resetSyncWatermark() }

        let today = Date.now
        let yesterday = today.addingTimeInterval(-86_400)
        let healthKit = MockHealthKitStepsService(samples: [
            HealthKitStepsSample(id: "sample-1", steps: 6_000, date: yesterday),
            HealthKitStepsSample(id: "sample-2", steps: 8_000, date: today)
        ])
        let manager = await TestManagers.signedInStepsManager(healthKitService: healthKit)

        await manager.backfillStepsFromHealthKit(userId: "author-1")

        #expect(await TestManagers.eventually { manager.stepsHistory.count == 2 })
        #expect(manager.stepsHistory.allSatisfy { $0.source == .healthkit })
        #expect(Set(manager.stepsHistory.map(\.healthKitId)) == ["sample-1", "sample-2"])
    }

    @Test("Test Backfill Only Imports Samples On Or After The User's Creation Date")
    func testBackfillOnlyImportsSamplesOnOrAfterTheUsersCreationDate() async {
        resetSyncWatermark()
        defer { resetSyncWatermark() }

        let creationDate = Date.now.addingTimeInterval(-10 * 86_400)
        let beforeCreation = creationDate.addingTimeInterval(-5 * 86_400)
        let afterCreation = creationDate.addingTimeInterval(2 * 86_400)
        let healthKit = MockHealthKitStepsService(samples: [
            HealthKitStepsSample(id: "too-early", steps: 3_000, date: beforeCreation),
            HealthKitStepsSample(id: "in-range", steps: 9_000, date: afterCreation)
        ])
        let manager = await TestManagers.signedInStepsManager(healthKitService: healthKit)

        await manager.backfillStepsFromHealthKit(userId: "author-1", userCreationDate: creationDate)

        #expect(await TestManagers.eventually { manager.stepsHistory.count == 1 })
        #expect(manager.stepsHistory.first?.healthKitId == "in-range")
    }

    @Test("Test Backfill Leaves History Empty When The Service Throws")
    func testBackfillLeavesHistoryEmptyWhenTheServiceThrows() async {
        resetSyncWatermark()
        defer { resetSyncWatermark() }

        let healthKit = MockHealthKitStepsService(samples: [
            HealthKitStepsSample(id: "sample-1", steps: 6_000, date: .now)
        ])
        healthKit.errorToThrow = HealthKitStepsServiceError.healthDataUnavailable
        let manager = await TestManagers.signedInStepsManager(healthKitService: healthKit)

        await manager.backfillStepsFromHealthKit(userId: "author-1")

        #expect(manager.stepsHistory.isEmpty)
    }

    // MARK: - Sync: dedup against what is already imported

    @Test("Test Sync Imports New Samples Alongside Existing History")
    func testSyncImportsNewSamplesAlongsideExistingHistory() async {
        resetSyncWatermark()
        defer { resetSyncWatermark() }

        let existing = entry(number: 4_000, date: Date.now.addingTimeInterval(-2 * 86_400))
        let healthKit = MockHealthKitStepsService(samples: [
            HealthKitStepsSample(id: "sample-1", steps: 7_000, date: .now)
        ])
        let manager = await TestManagers.signedInStepsManager(entries: [existing], healthKitService: healthKit)

        await manager.syncWithHealthKit(userId: "author-1")

        #expect(await TestManagers.eventually { manager.stepsHistory.count == 2 })
    }

    @Test("Test Sync Skips A Sample Already Imported By Its HealthKit Id")
    func testSyncSkipsASampleAlreadyImportedByItsHealthKitId() async {
        resetSyncWatermark()
        defer { resetSyncWatermark() }

        let sampleDate = Date.now
        let alreadyImported = entry(number: 7_000, date: sampleDate, healthKitId: "sample-1")
        let healthKit = MockHealthKitStepsService(samples: [
            HealthKitStepsSample(id: "sample-1", steps: 7_000, date: sampleDate)
        ])
        let manager = await TestManagers.signedInStepsManager(entries: [alreadyImported], healthKitService: healthKit)

        await manager.syncWithHealthKit(userId: "author-1")

        // Nothing further to await: with the one sample skipped, `saveDocument` is never called,
        // so there is no listener emission left to race.
        #expect(manager.stepsHistory.count == 1)
    }

    @Test("Test Sync Skips A Sample At Or Below The Day's Existing Maximum")
    func testSyncSkipsASampleAtOrBelowTheDaysExistingMaximum() async {
        resetSyncWatermark()
        defer { resetSyncWatermark() }

        let day = Date.now
        let existing = entry(number: 10_000, date: day)
        let healthKit = MockHealthKitStepsService(samples: [
            HealthKitStepsSample(id: "lower", steps: 8_000, date: day),
            HealthKitStepsSample(id: "equal", steps: 10_000, date: day)
        ])
        let manager = await TestManagers.signedInStepsManager(entries: [existing], healthKitService: healthKit)

        await manager.syncWithHealthKit(userId: "author-1")

        #expect(manager.stepsHistory.count == 1)
    }

    @Test("Test Sync Imports A Sample That Beats The Day's Existing Maximum")
    func testSyncImportsASampleThatBeatsTheDaysExistingMaximum() async {
        resetSyncWatermark()
        defer { resetSyncWatermark() }

        let day = Date.now
        let existing = entry(number: 5_000, date: day)
        let healthKit = MockHealthKitStepsService(samples: [
            HealthKitStepsSample(id: "higher", steps: 12_000, date: day)
        ])
        let manager = await TestManagers.signedInStepsManager(entries: [existing], healthKitService: healthKit)

        await manager.syncWithHealthKit(userId: "author-1")

        #expect(await TestManagers.eventually { manager.stepsHistory.count == 2 })
    }

    /// A day max only counts entries for the user being synced and not soft-deleted, so another
    /// user's steps (following/shared data, if it ever lands in the same collection) or a
    /// cleared entry cannot mask a real import.
    @Test("Test A Day Max Only Considers The Synced User's Own, Undeleted Entries")
    func testADayMaxOnlyConsidersTheSyncedUsersOwnUndeletedEntries() async {
        resetSyncWatermark()
        defer { resetSyncWatermark() }

        let day = Date.now
        let otherUsersEntry = entry(number: 20_000, date: day, authorId: "someone-else")
        let deletedEntry = entry(number: 20_000, date: day, deletedAt: .now)
        let healthKit = MockHealthKitStepsService(samples: [
            HealthKitStepsSample(id: "sample-1", steps: 9_000, date: day)
        ])
        let manager = await TestManagers.signedInStepsManager(
            entries: [otherUsersEntry, deletedEntry],
            healthKitService: healthKit
        )

        await manager.syncWithHealthKit(userId: "author-1")

        #expect(await TestManagers.eventually { manager.stepsHistory.count == 3 })
    }

    @Test("Test Sync Leaves History Untouched When The Service Throws")
    func testSyncLeavesHistoryUntouchedWhenTheServiceThrows() async {
        resetSyncWatermark()
        defer { resetSyncWatermark() }

        let existing = entry(number: 4_000, date: .now)
        let healthKit = MockHealthKitStepsService(samples: [
            HealthKitStepsSample(id: "sample-1", steps: 7_000, date: .now)
        ])
        healthKit.errorToThrow = HealthKitStepsServiceError.healthDataUnavailable
        let manager = await TestManagers.signedInStepsManager(entries: [existing], healthKitService: healthKit)

        await manager.syncWithHealthKit(userId: "author-1")

        #expect(manager.stepsHistory.count == 1)
    }

    // MARK: - Sync watermark

    /// A second sync should not re-import what the first already pulled in, because the manager
    /// advances its "last synced" watermark to the newest sample's date and passes it back to
    /// the service as `since`. The mock filters on `date > since`, so a second call with no new
    /// samples must return nothing to import.
    @Test("Test A Second Sync Does Not Reimport What The First Already Pulled In")
    func testASecondSyncDoesNotReimportWhatTheFirstAlreadyPulledIn() async {
        resetSyncWatermark()
        defer { resetSyncWatermark() }

        let healthKit = MockHealthKitStepsService(samples: [
            HealthKitStepsSample(id: "sample-1", steps: 6_000, date: .now)
        ])
        let manager = await TestManagers.signedInStepsManager(healthKitService: healthKit)

        await manager.syncWithHealthKit(userId: "author-1")
        #expect(await TestManagers.eventually { manager.stepsHistory.count == 1 })

        await manager.syncWithHealthKit(userId: "author-1")

        #expect(manager.stepsHistory.count == 1)
    }
}

#endif
