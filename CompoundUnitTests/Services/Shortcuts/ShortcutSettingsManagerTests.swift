//
//  ShortcutSettingsManagerTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 22/09/2026.
//

import Testing
import Foundation
@testable import Compound

/// The Add tab's quick actions.
///
/// Unlike the other settings documents this one stores the *visible* list, because its order is
/// the user's choice. Both facts — that nil means the defaults, and that order survives a
/// round trip — are what the screen depends on.
@MainActor
struct ShortcutSettingsManagerTests {

    private var storedSettings: ShortcutSettings {
        var settings = ShortcutSettings(authorId: "user-1")
        settings.setQuickActions([.browseRecipes, .logMeal])
        return settings
    }

    // MARK: - Reading

    @Test("Test The Default Actions Show Until Signed In")
    func testTheDefaultActionsShowUntilSignedIn() {
        let manager = TestManagers.shortcutSettingsManager(stored: storedSettings)

        // The grid draws before the listener emits, and an empty grid would be a broken tab.
        #expect(manager.shortcutSettings.quickActions == QuickAction.defaultActions)
    }

    @Test("Test Signing In Exposes The Chosen Actions In Order")
    func testSigningInExposesTheChosenActionsInOrder() async throws {
        let manager = TestManagers.shortcutSettingsManager(stored: storedSettings)

        try await manager.signIn(userId: "user-1", isNewUser: false)

        #expect(await TestManagers.eventually { manager.shortcutSettings.quickActions.count == 2 })
        #expect(manager.shortcutSettings.quickActions == [.browseRecipes, .logMeal])
    }

    @Test("Test A New User Gets The Default Actions")
    func testANewUserGetsTheDefaultActions() async throws {
        let manager = TestManagers.shortcutSettingsManager(stored: nil)

        try await manager.signIn(userId: "user-2", isNewUser: true)

        #expect(manager.shortcutSettings.authorId == "user-2")
        #expect(manager.shortcutSettings.quickActionIds == nil)
        #expect(manager.shortcutSettings.quickActions == QuickAction.defaultActions)
    }

    @Test("Test Signing Out Returns To The Default Actions")
    func testSigningOutReturnsToTheDefaultActions() async throws {
        let manager = TestManagers.shortcutSettingsManager(stored: storedSettings)
        try await manager.signIn(userId: "user-1", isNewUser: false)
        #expect(await TestManagers.eventually { manager.shortcutSettings.quickActions.count == 2 })

        manager.signOut()

        #expect(manager.shortcutSettings.quickActions == QuickAction.defaultActions)
    }

    // MARK: - Writing

    @Test("Test A Reordered List Is Saved In That Order")
    func testAReorderedListIsSavedInThatOrder() async throws {
        let manager = TestManagers.shortcutSettingsManager(stored: nil)
        try await manager.signIn(userId: "user-1", isNewUser: true)

        var settings = manager.shortcutSettings
        settings.setQuickActions([.logWeight, .startWorkout, .browseExercises])
        try await manager.saveSettings(settings)

        #expect(await TestManagers.eventually { manager.shortcutSettings.quickActions.count == 3 })
        #expect(manager.shortcutSettings.quickActions == [.logWeight, .startWorkout, .browseExercises])
    }

    /// Clearing every shortcut is a choice, not a reset: an empty stored list must stay empty
    /// rather than springing back to the four defaults, which only `nil` means.
    @Test("Test An Empty Chosen List Stays Empty")
    func testAnEmptyChosenListStaysEmpty() async throws {
        let manager = TestManagers.shortcutSettingsManager(stored: nil)
        try await manager.signIn(userId: "user-1", isNewUser: true)

        var settings = manager.shortcutSettings
        settings.setQuickActions([])
        try await manager.saveSettings(settings)

        #expect(await TestManagers.eventually { manager.shortcutSettings.quickActionIds == [] })
        #expect(manager.shortcutSettings.quickActions.isEmpty)
    }

    /// An action dropped in a later release leaves the rest of a curated list intact rather than
    /// failing the read.
    @Test("Test An Unknown Stored Action Is Dropped From The List")
    func testAnUnknownStoredActionIsDroppedFromTheList() async throws {
        var stored = ShortcutSettings(authorId: "user-1")
        stored.quickActionIds = ["log_meal", "retired_action", "log_weight"]
        let manager = TestManagers.shortcutSettingsManager(stored: stored)

        try await manager.signIn(userId: "user-1", isNewUser: false)

        #expect(await TestManagers.eventually { manager.shortcutSettings.quickActions.count == 2 })
        #expect(manager.shortcutSettings.quickActions == [.logMeal, .logWeight])
    }

    @Test("Test A Stale Shortcut Save Reverts A List Chosen In Between")
    func testAStaleShortcutSaveRevertsAListChosenInBetween() async throws {
        // Stored with the defaults spelled out rather than as nil, so the wait below is only
        // satisfied once the listener has actually emitted.
        var stored = ShortcutSettings(authorId: "user-1")
        stored.setQuickActions(QuickAction.defaultActions)
        let manager = TestManagers.shortcutSettingsManager(stored: stored)
        try await manager.signIn(userId: "user-1", isNewUser: false)
        #expect(await TestManagers.eventually { manager.shortcutSettings.quickActionIds != nil })

        let staleCopy = manager.shortcutSettings

        var chosen = manager.shortcutSettings
        chosen.setQuickActions([.browseRecipes])
        try await manager.saveSettings(chosen)
        #expect(await TestManagers.eventually { manager.shortcutSettings.quickActions == [.browseRecipes] })

        // Saving the older copy puts the list back, with nothing to say a choice was lost.
        try await manager.saveSettings(staleCopy)

        #expect(await TestManagers.eventually { manager.shortcutSettings.quickActions == QuickAction.defaultActions })
    }
}
