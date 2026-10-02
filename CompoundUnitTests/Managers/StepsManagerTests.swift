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

/// `StepsManager`'s Apple Health import against an in-memory Health: one entry per day holding
/// that day's total, kept up to date as Health changes.
///
/// The import's anchor is kept in UserDefaults per user, so each import test signs in as a user
/// of its own.
@MainActor
struct StepsManagerTests {

    private func entry(number: Int, date: Date, authorId: String = "author-1", source: StepsSource = .manual) -> StepsModel {
        StepsModel(authorId: authorId, number: number, date: date, source: source)
    }

    private static let today = Calendar.current.startOfDay(for: .now)
    private static let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

    private func walk(_ steps: Int, on day: Date, hour: Double = 9) -> MockStepsSample {
        MockStepsSample(steps: steps, date: day.addingTimeInterval(hour * 3600))
    }

    private func signedInWithHealth(
        _ health: MockHealthKitStepsService,
        userId: String = UUID().uuidString,
        entries: [StepsModel] = [],
        importSince: Date? = nil
    ) async -> StepsManager {
        let manager = TestManagers.stepsManager(entries: entries, healthKitService: health)
        await manager.signIn(userId: userId, importSince: importSince)
        return manager
    }

    private func total(_ manager: StepsManager, on day: Date) -> Int? {
        manager.stepsHistory.first { Calendar.current.isDate($0.date, inSameDayAs: day) }?.number
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

    // MARK: - Apple Health import

    @Test("Test Signing In Imports One Total Per Day")
    func testSigningInImportsOneTotalPerDay() async {
        let health = MockHealthKitStepsService(samples: [
            walk(3_000, on: Self.yesterday), walk(3_000, on: Self.yesterday, hour: 18), walk(8_000, on: Self.today)
        ])
        let manager = await signedInWithHealth(health)

        #expect(await TestManagers.eventually { manager.stepsHistory.count == 2 })
        #expect(total(manager, on: Self.yesterday) == 6_000)
        #expect(total(manager, on: Self.today) == 8_000)
        #expect(manager.stepsHistory.allSatisfy { $0.source == .healthkit })
    }

    /// Today's total keeps rising as Health records more; it used to freeze at the first import.
    @Test("Test More Steps In Apple Health Update The Day")
    func testMoreStepsInAppleHealthUpdateTheDay() async {
        let health = MockHealthKitStepsService(samples: [walk(2_000, on: Self.today)])
        let manager = await signedInWithHealth(health)
        _ = await TestManagers.eventually { total(manager, on: Self.today) == 2_000 }

        health.add(walk(1_500, on: Self.today, hour: 15))

        #expect(await TestManagers.eventually { total(manager, on: Self.today) == 3_500 })
        #expect(manager.stepsHistory.count == 1)
    }

    /// A late sync for an earlier day, the Watch catching up say, still reaches that day.
    @Test("Test Steps Synced Late For An Earlier Day Are Imported")
    func testStepsSyncedLateForAnEarlierDayAreImported() async {
        let health = MockHealthKitStepsService(samples: [walk(8_000, on: Self.today)])
        let manager = await signedInWithHealth(health)
        _ = await TestManagers.eventually { manager.stepsHistory.count == 1 }

        health.add(walk(4_000, on: Self.yesterday))

        #expect(await TestManagers.eventually { total(manager, on: Self.yesterday) == 4_000 })
    }

    @Test("Test Deleting In Apple Health Recounts The Day")
    func testDeletingInAppleHealthRecountsTheDay() async {
        let removed = walk(1_000, on: Self.today, hour: 15)
        let health = MockHealthKitStepsService(samples: [walk(5_000, on: Self.today), removed])
        let manager = await signedInWithHealth(health)
        _ = await TestManagers.eventually { total(manager, on: Self.today) == 6_000 }

        health.delete(removed.uuid)

        #expect(await TestManagers.eventually { total(manager, on: Self.today) == 5_000 })
    }

    @Test("Test Steps Before The Import Start Are Left Out")
    func testStepsBeforeTheImportStartAreLeftOut() async {
        let health = MockHealthKitStepsService(samples: [walk(3_000, on: Self.yesterday), walk(9_000, on: Self.today)])
        let manager = await signedInWithHealth(health, importSince: Self.today)

        #expect(await TestManagers.eventually { manager.stepsHistory.count == 1 })
        #expect(total(manager, on: Self.today) == 9_000)
    }

    /// A count entered here that is already as high is not doubled up with an import.
    @Test("Test A Higher Count Entered Here Wins The Day")
    func testAHigherCountEnteredHereWinsTheDay() async {
        let userId = UUID().uuidString
        let entered = entry(number: 10_000, date: Self.today, authorId: userId)
        let health = MockHealthKitStepsService(samples: [walk(7_000, on: Self.today)])
        let manager = await signedInWithHealth(health, userId: userId, entries: [entered])
        _ = await TestManagers.eventually { manager.stepsHistory.count == 1 }

        let doubled = await TestManagers.eventually(timeout: .milliseconds(500)) { manager.stepsHistory.count > 1 }

        #expect(!doubled)
    }

    /// Every steps screen restarts the import as it opens. That used to cancel a pass part-way
    /// through, before its anchor was stored, so the catch-up started over on every launch.
    @Test("Test Restarting The Import Does Not Abandon A Pass In Progress")
    func testRestartingTheImportDoesNotAbandonAPassInProgress() async {
        let userId = UUID().uuidString
        let health = MockHealthKitStepsService(samples: [walk(8_000, on: Self.today)])
        health.readDelay = .milliseconds(300)
        let manager = await signedInWithHealth(health, userId: userId)

        manager.startHealthKitImport(userId: userId, since: nil)

        #expect(await TestManagers.eventually { total(manager, on: Self.today) == 8_000 })
        #expect(await TestManagers.eventually { UserDefaults.standard.data(forKey: "healthkit.steps.anchor.\(userId)") != nil })
    }

    @Test("Test A Failing Read Imports Nothing")
    func testAFailingReadImportsNothing() async {
        let health = MockHealthKitStepsService(samples: [walk(6_000, on: Self.today)])
        health.errorToThrow = HealthKitStepsServiceError.healthDataUnavailable
        let manager = await signedInWithHealth(health)

        let imported = await TestManagers.eventually(timeout: .milliseconds(500)) { !manager.stepsHistory.isEmpty }

        #expect(!imported)
    }
}

#endif
