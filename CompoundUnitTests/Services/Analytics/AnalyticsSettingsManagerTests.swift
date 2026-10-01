//
//  AnalyticsSettingsManagerTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 22/09/2026.
//

import Testing
import Foundation
@testable import Compound

/// Which sections the Analytics tab shows.
///
/// The document stores what is *hidden*, so the interesting cases are the empty one (everything
/// visible) and a stored id for a section that no longer exists.
@MainActor
struct AnalyticsSettingsManagerTests {

    private var storedSettings: AnalyticsSettings {
        AnalyticsSettings(authorId: "user-1", hiddenSectionIds: ["habits", "exercises"])
    }

    // MARK: - Reading

    @Test("Test Every Section Is Visible Until Signed In")
    func testEverySectionIsVisibleUntilSignedIn() {
        let manager = TestManagers.analyticsSettingsManager(stored: storedSettings)

        // The tab renders before the listener emits, and an unreadable document must not blank it.
        #expect(AnalyticsSection.allCases.allSatisfy { manager.analyticsSettings.isVisible($0) })
    }

    @Test("Test Signing In Exposes The Hidden Sections")
    func testSigningInExposesTheHiddenSections() async throws {
        let manager = TestManagers.analyticsSettingsManager(stored: storedSettings)

        try await manager.signIn(userId: "user-1", isNewUser: false)

        #expect(await TestManagers.eventually { manager.analyticsSettings.hiddenSectionIds.count == 2 })
        #expect(manager.analyticsSettings.isVisible(.habits) == false)
        #expect(manager.analyticsSettings.isVisible(.nutrition))
    }

    @Test("Test A New User Hides Nothing")
    func testANewUserHidesNothing() async throws {
        let manager = TestManagers.analyticsSettingsManager(stored: nil)

        try await manager.signIn(userId: "user-2", isNewUser: true)

        #expect(manager.analyticsSettings.authorId == "user-2")
        #expect(manager.analyticsSettings.hiddenSectionIds.isEmpty)
    }

    @Test("Test Signing Out Returns To Everything Visible")
    func testSigningOutReturnsToEverythingVisible() async throws {
        let manager = TestManagers.analyticsSettingsManager(stored: storedSettings)
        try await manager.signIn(userId: "user-1", isNewUser: false)
        #expect(await TestManagers.eventually { manager.analyticsSettings.hiddenSectionIds.count == 2 })

        manager.signOut()

        #expect(manager.analyticsSettings.hiddenSectionIds.isEmpty)
    }

    // MARK: - Writing

    @Test("Test Hiding A Section Is Saved")
    func testHidingASectionIsSaved() async throws {
        let manager = TestManagers.analyticsSettingsManager(stored: nil)
        try await manager.signIn(userId: "user-1", isNewUser: true)

        var settings = manager.analyticsSettings
        settings.setVisible(false, for: .muscleGroups)
        try await manager.saveSettings(settings)

        #expect(await TestManagers.eventually { manager.analyticsSettings.isVisible(.muscleGroups) == false })
        #expect(manager.analyticsSettings.hiddenSectionIds == ["muscle_groups"])
    }

    @Test("Test Showing A Hidden Section Again Is Saved")
    func testShowingAHiddenSectionAgainIsSaved() async throws {
        let manager = TestManagers.analyticsSettingsManager(stored: storedSettings)
        try await manager.signIn(userId: "user-1", isNewUser: false)
        #expect(await TestManagers.eventually { manager.analyticsSettings.isVisible(.habits) == false })

        var settings = manager.analyticsSettings
        settings.setVisible(true, for: .habits)
        try await manager.saveSettings(settings)

        #expect(await TestManagers.eventually { manager.analyticsSettings.isVisible(.habits) })
        #expect(manager.analyticsSettings.isVisible(.exercises) == false)
    }

    /// A section id written by a build that has since dropped it stays in the document rather than
    /// being silently rewritten — the reader ignores what it does not recognise.
    @Test("Test An Unknown Hidden Section Id Is Harmless")
    func testAnUnknownHiddenSectionIdIsHarmless() async throws {
        let stored = AnalyticsSettings(authorId: "user-1", hiddenSectionIds: ["retired_section"])
        let manager = TestManagers.analyticsSettingsManager(stored: stored)

        try await manager.signIn(userId: "user-1", isNewUser: false)

        #expect(await TestManagers.eventually { manager.analyticsSettings.hiddenSectionIds == ["retired_section"] })
        #expect(AnalyticsSection.allCases.allSatisfy { manager.analyticsSettings.isVisible($0) })
    }

    /// The same whole-document write this app's settings all use, so the same lost update.
    @Test("Test A Stale Analytics Save Drops A Section Hidden In Between")
    func testAStaleAnalyticsSaveDropsASectionHiddenInBetween() async throws {
        // Stored with one section already hidden, so the wait below cannot be satisfied by the
        // fallback document the manager serves before the listener emits.
        let stored = AnalyticsSettings(authorId: "user-1", hiddenSectionIds: ["body_metrics"])
        let manager = TestManagers.analyticsSettingsManager(stored: stored)
        try await manager.signIn(userId: "user-1", isNewUser: false)
        #expect(await TestManagers.eventually { manager.analyticsSettings.isVisible(.bodyMetrics) == false })

        let staleCopy = manager.analyticsSettings

        var hidingHabits = manager.analyticsSettings
        hidingHabits.setVisible(false, for: .habits)
        try await manager.saveSettings(hidingHabits)
        #expect(await TestManagers.eventually { manager.analyticsSettings.isVisible(.habits) == false })

        var fromStale = staleCopy
        fromStale.setVisible(false, for: .nutrition)
        try await manager.saveSettings(fromStale)

        #expect(await TestManagers.eventually { manager.analyticsSettings.isVisible(.nutrition) == false })
        #expect(manager.analyticsSettings.isVisible(.habits))
    }
}
