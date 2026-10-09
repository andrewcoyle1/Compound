//
//  NutritionStrategySettingsManagerTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 22/09/2026.
//

import Testing
import Foundation
@testable import Compound

/// The Strategy and Expenditure settings, which share one document.
///
/// `bmrEquation` and `estimationMethod` are the two fields that change a number the user sees, so
/// they matter more than the rest — and `resolvedBMREquation(bodyFatPercentage:)` reads both.
@MainActor
struct NutritionStrategySettingsManagerTests {

    private var storedSettings: NutritionStrategySettings {
        var settings = NutritionStrategySettings(authorId: "user-1")
        settings.checkInWeekday = 6
        settings.fastCheckIn = true
        settings.bmrEquation = .harrisBenedict
        settings.estimationMethod = .bodyFatAware
        settings.stepInformedUpdates = true
        return settings
    }

    // MARK: - Reading

    @Test("Test Settings Are Defaults Until Signed In")
    func testStrategySettingsAreDefaultsUntilSignedIn() {
        let manager = TestManagers.nutritionStrategySettingsManager(stored: storedSettings)

        // The expenditure estimate runs off these before the listener emits, so the fallback has
        // to be the documented default rather than anything empty.
        #expect(manager.nutritionStrategySettings.bmrEquation == .mifflinStJeor)
        #expect(manager.nutritionStrategySettings.estimationMethod == .standard)
        #expect(manager.nutritionStrategySettings.checkInWeekday == 2)
    }

    @Test("Test Signing In Exposes The Stored Strategy")
    func testSigningInExposesTheStoredStrategy() async throws {
        let manager = TestManagers.nutritionStrategySettingsManager(stored: storedSettings)

        try await manager.signIn(userId: "user-1", isNewUser: false)

        #expect(await TestManagers.eventually { manager.nutritionStrategySettings.checkInWeekday == 6 })
        #expect(manager.nutritionStrategySettings.bmrEquation == .harrisBenedict)
        #expect(manager.nutritionStrategySettings.estimationMethod == .bodyFatAware)
        #expect(manager.nutritionStrategySettings.fastCheckIn)
        #expect(manager.nutritionStrategySettings.stepInformedUpdates)
    }

    @Test("Test A New User Reads The Default Strategy Under Their Own Id")
    func testANewUserReadsTheDefaultStrategyUnderTheirOwnId() async throws {
        let manager = TestManagers.nutritionStrategySettingsManager(stored: nil)

        try await manager.signIn(userId: "user-2", isNewUser: true)

        #expect(manager.nutritionStrategySettings.authorId == "user-2")
        #expect(manager.nutritionStrategySettings.bmrEquation == .mifflinStJeor)
    }

    @Test("Test Signing Out Returns To The Default Strategy")
    func testSigningOutReturnsToTheDefaultStrategy() async throws {
        let manager = TestManagers.nutritionStrategySettingsManager(stored: storedSettings)
        try await manager.signIn(userId: "user-1", isNewUser: false)
        #expect(await TestManagers.eventually { manager.nutritionStrategySettings.checkInWeekday == 6 })

        manager.signOut()

        #expect(manager.nutritionStrategySettings.checkInWeekday == 2)
        #expect(manager.nutritionStrategySettings.bmrEquation == .mifflinStJeor)
    }

    // MARK: - Writing

    @Test("Test A Chosen BMR Equation Is Saved")
    func testAChosenBMREquationIsSaved() async throws {
        let manager = TestManagers.nutritionStrategySettingsManager(stored: nil)
        try await manager.signIn(userId: "user-1", isNewUser: true)

        var settings = manager.nutritionStrategySettings
        settings.bmrEquation = .cunningham
        try await manager.saveSettings(settings)

        #expect(await TestManagers.eventually { manager.nutritionStrategySettings.bmrEquation == .cunningham })
    }

    /// A date is the one non-primitive field in this document, so it is the one most likely to be
    /// lost in a round trip.
    @Test("Test A Calculation Start Date Survives A Round Trip")
    func testACalculationStartDateSurvivesARoundTrip() async throws {
        let manager = TestManagers.nutritionStrategySettingsManager(stored: nil)
        try await manager.signIn(userId: "user-1", isNewUser: true)
        let startDate = Date(timeIntervalSince1970: 1_750_000_000)

        var settings = manager.nutritionStrategySettings
        settings.calculationStartDate = startDate
        try await manager.saveSettings(settings)

        #expect(await TestManagers.eventually { manager.nutritionStrategySettings.calculationStartDate == startDate })
    }

    @Test("Test Turning Off Every Strategy Toggle Is Saved")
    func testTurningOffEveryStrategyToggleIsSaved() async throws {
        let manager = TestManagers.nutritionStrategySettingsManager(stored: nil)
        try await manager.signIn(userId: "user-1", isNewUser: true)

        // All four default to true, so saving false is the direction that a "save only what is
        // set" bug would silently drop.
        var settings = manager.nutritionStrategySettings
        settings.partialLoggingEnabled = false
        settings.weighInEnabled = false
        settings.fastingEnabled = false
        settings.loggingBreakEnabled = false
        try await manager.saveSettings(settings)

        #expect(await TestManagers.eventually { manager.nutritionStrategySettings.fastingEnabled == false })
        #expect(manager.nutritionStrategySettings.partialLoggingEnabled == false)
        #expect(manager.nutritionStrategySettings.weighInEnabled == false)
        #expect(manager.nutritionStrategySettings.loggingBreakEnabled == false)
    }

    /// The saved pair is what the estimate actually runs, so the manager's round trip has to
    /// preserve the combination, not just each field.
    @Test("Test The Saved Pair Still Resolves To Cunningham")
    func testTheSavedPairStillResolvesToCunningham() async throws {
        let manager = TestManagers.nutritionStrategySettingsManager(stored: nil)
        try await manager.signIn(userId: "user-1", isNewUser: true)

        var settings = manager.nutritionStrategySettings
        settings.estimationMethod = .bodyFatAware
        settings.bmrEquation = .mifflinStJeor
        try await manager.saveSettings(settings)

        #expect(await TestManagers.eventually {
            manager.nutritionStrategySettings.estimationMethod == .bodyFatAware
        })
        #expect(manager.nutritionStrategySettings.resolvedBMREquation(bodyFatPercentage: 18) == .cunningham)
        #expect(manager.nutritionStrategySettings.resolvedBMREquation(bodyFatPercentage: nil) == .mifflinStJeor)
    }

    @Test("Test A Stale Strategy Save Reverts A Choice Made In Between")
    func testAStaleStrategySaveRevertsAChoiceMadeInBetween() async throws {
        var stored = NutritionStrategySettings(authorId: "user-1")
        stored.checkInWeekday = 5
        let manager = TestManagers.nutritionStrategySettingsManager(stored: stored)
        try await manager.signIn(userId: "user-1", isNewUser: false)
        #expect(await TestManagers.eventually { manager.nutritionStrategySettings.checkInWeekday == 5 })

        // The Expenditure screen's copy, taken before the Strategy screen saves.
        var expenditureCopy = manager.nutritionStrategySettings

        var strategyCopy = manager.nutritionStrategySettings
        strategyCopy.checkInWeekday = 1
        try await manager.saveSettings(strategyCopy)
        #expect(await TestManagers.eventually { manager.nutritionStrategySettings.checkInWeekday == 1 })

        expenditureCopy.bmrEquation = .harrisBenedict
        try await manager.saveSettings(expenditureCopy)

        #expect(await TestManagers.eventually { manager.nutritionStrategySettings.bmrEquation == .harrisBenedict })
        #expect(manager.nutritionStrategySettings.checkInWeekday == 5)
    }
}
