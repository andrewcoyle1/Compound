//
//  FoodLogSettingsManagerTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 22/09/2026.
//

import Testing
import Foundation
@testable import Compound

/// The one settings document that also carries user content.
///
/// `FoodLogSettings` holds seven screens' worth of toggles *and* `favouriteFoodIds` /
/// `favouriteRecipeIds`, which the nutrition tab writes. Everything here writes the whole
/// document back, so every write is a chance to lose somebody else's field — which makes the
/// manager's own guarantees worth stating precisely rather than assuming.
@MainActor
struct FoodLogSettingsManagerTests {

    /// Stored settings that differ from the defaults in every way this suite looks at, so an
    /// assertion cannot pass by accidentally matching a fresh document.
    private var storedSettings: FoodLogSettings {
        var settings = FoodLogSettings(authorId: "user-1")
        settings.favouriteFoodIds = ["food-1", "food-2"]
        settings.favouriteRecipeIds = ["recipe-1"]
        settings.startHour = 4
        settings.quickAddEnabled = true
        settings.favouriteMeasurements = ["tbsp"]
        return settings
    }

    // MARK: - Reading

    @Test("Test Settings Are Defaults Until Signed In")
    func testSettingsAreDefaultsUntilSignedIn() {
        let manager = TestManagers.foodLogSettingsManager(stored: storedSettings)

        // Not merely "empty": the fallback has to be a usable document, because every screen reads
        // it before the listener has said anything.
        #expect(manager.foodLogSettings.favouriteFoodIds.isEmpty)
        #expect(manager.foodLogSettings.startHour == 7)
        #expect(manager.foodLogSettings.authorId.isEmpty)
    }

    /// The regression this manager's sign-in race caused: `startListening` does not wait for its
    /// listener's first emission, so a naive `if currentDocument == nil { saveDocument(default) }`
    /// almost always sees `nil` and overwrites an existing document before the listener ever
    /// delivers it — this suite is what caught that. `isNewUser` is the fix, and this proves it
    /// holds even when nothing is cached *yet*, not just when a fetch happens to succeed: an
    /// existing user's `signIn` must not attempt a save at all. The engine's own remote (see
    /// `RemoteDocumentService.getDocument(id:)`) is documented to throw for "not found *or* fetch
    /// fails" with no way to catch only the first — so "only save on a real fetch failure" cannot
    /// be made safe, and the manager does not try; it never fetches to decide in the first place.
    @Test("Test An Existing User's Sign In Never Attempts A Save")
    func testAnExistingUsersSignInNeverAttemptsASave() async throws {
        let manager = TestManagers.foodLogSettingsManager(stored: storedSettings)

        // The mock remote's only slow operation is `saveDocument`, a flat 0.5s sleep (see
        // `MockRemoteDocumentService`). Returning well under that is proof `signIn` never called
        // it for an existing user — not a race, since 0.5s is a floor the mock sleeps at least,
        // never less.
        let start = ContinuousClock.now
        try await manager.signIn(userId: "user-1", isNewUser: false)
        let elapsed = start.duration(to: .now)
        #expect(elapsed < .milliseconds(400))

        // And the document that was already there really did survive, untouched, once the
        // listener catches up — the assertion a spurious overwrite would fail.
        #expect(await TestManagers.eventually { manager.foodLogSettings.favouriteFoodIds == ["food-1", "food-2"] })
        #expect(manager.foodLogSettings.favouriteRecipeIds == ["recipe-1"])
    }

    @Test("Test Signing In Exposes The Stored Settings")
    func testSigningInExposesTheStoredSettings() async throws {
        let manager = TestManagers.foodLogSettingsManager(stored: storedSettings)

        try await manager.signIn(userId: "user-1", isNewUser: false)

        #expect(await TestManagers.eventually { manager.foodLogSettings.startHour == 4 })
        #expect(manager.foodLogSettings.quickAddEnabled)
        #expect(manager.foodLogSettings.favouriteMeasurements == ["tbsp"])
    }

    /// The reason this manager matters. Favourites are user content, not a preference — losing
    /// them at sign-in is indistinguishable from the user never having saved them.
    @Test("Test Signing In Keeps Favourites Saved On Another Device")
    func testSigningInKeepsFavouritesSavedOnAnotherDevice() async throws {
        let manager = TestManagers.foodLogSettingsManager(stored: storedSettings)

        try await manager.signIn(userId: "user-1", isNewUser: false)

        #expect(await TestManagers.eventually { manager.foodLogSettings.favouriteFoodIds == ["food-1", "food-2"] })
        #expect(manager.foodLogSettings.favouriteRecipeIds == ["recipe-1"])
    }

    /// A user who has never saved anything still needs a document to read, and it has to be
    /// attributed to them — `authorId` is what the remote store's rules match on.
    @Test("Test A New User Reads Defaults Under Their Own Id")
    func testANewUserReadsDefaultsUnderTheirOwnId() async throws {
        let manager = TestManagers.foodLogSettingsManager(stored: nil)

        try await manager.signIn(userId: "user-2", isNewUser: true)

        // Read straight out, with no `eventually`: the id comes from the sign-in itself, so a wait
        // here would pass before the listener had done anything at all.
        #expect(manager.foodLogSettings.authorId == "user-2")
        #expect(manager.foodLogSettings.startHour == 7)
        #expect(manager.foodLogSettings.favouriteFoodIds.isEmpty)
    }

    @Test("Test Signing Out Returns To Defaults")
    func testSigningOutReturnsToDefaults() async throws {
        let manager = TestManagers.foodLogSettingsManager(stored: storedSettings)
        try await manager.signIn(userId: "user-1", isNewUser: false)
        #expect(await TestManagers.eventually { manager.foodLogSettings.startHour == 4 })

        manager.signOut()

        // One user's favourites must not be visible to whoever signs in next on the same device.
        #expect(manager.foodLogSettings.favouriteFoodIds.isEmpty)
        #expect(manager.foodLogSettings.startHour == 7)
    }

    // MARK: - Writing

    @Test("Test Saved Settings Are Read Back")
    func testSavedSettingsAreReadBack() async throws {
        let manager = TestManagers.foodLogSettingsManager(stored: nil)
        try await manager.signIn(userId: "user-1", isNewUser: true)

        var settings = manager.foodLogSettings
        settings.hideEmptyHours = true
        settings.endHour = 21
        settings.timestampSide = .right
        try await manager.saveSettings(settings)

        #expect(await TestManagers.eventually { manager.foodLogSettings.hideEmptyHours })
        #expect(manager.foodLogSettings.endHour == 21)
        #expect(manager.foodLogSettings.timestampSide == .right)
    }

    @Test("Test Saving A Toggle Keeps The Favourites Alongside It")
    func testSavingAToggleKeepsTheFavouritesAlongsideIt() async throws {
        let manager = TestManagers.foodLogSettingsManager(stored: storedSettings)
        try await manager.signIn(userId: "user-1", isNewUser: false)
        #expect(await TestManagers.eventually { manager.foodLogSettings.favouriteFoodIds.count == 2 })

        var settings = manager.foodLogSettings
        settings.showProteinRing = false
        try await manager.saveSettings(settings)

        #expect(await TestManagers.eventually { manager.foodLogSettings.showProteinRing == false })
        #expect(manager.foodLogSettings.favouriteFoodIds == ["food-1", "food-2"])
    }

    @Test("Test Saving Empty Favourites Clears Them Rather Than Being Ignored")
    func testSavingEmptyFavouritesClearsThemRatherThanBeingIgnored() async throws {
        let manager = TestManagers.foodLogSettingsManager(stored: storedSettings)
        try await manager.signIn(userId: "user-1", isNewUser: false)
        #expect(await TestManagers.eventually { manager.foodLogSettings.favouriteFoodIds.count == 2 })

        // Unfavouriting the last food is a legitimate write of an empty list, so the manager must
        // not treat empty as "no change".
        var settings = manager.foodLogSettings
        settings.favouriteFoodIds = []
        try await manager.saveSettings(settings)

        #expect(await TestManagers.eventually { manager.foodLogSettings.favouriteFoodIds.isEmpty })
        #expect(manager.foodLogSettings.favouriteRecipeIds == ["recipe-1"])
    }

    // MARK: - Interleaved writes

    /// What the manager does *not* promise, stated so nobody assumes otherwise.
    ///
    /// `saveSettings` writes the whole document. Two writers holding their own copies therefore
    /// race, and the later write wins outright — the earlier writer's field is gone, with no
    /// error and nothing in the document to say it happened. The presenters re-read in
    /// `onViewAppear` to shrink that window, but the manager offers no merge, so anything holding
    /// a copy across an `await` can still lose a favourite. See
    /// `FoodLogSettingsStaleSnapshotTests` for the presenter-layer guard.
    @Test("Test A Stale Whole Document Save Drops A Favourite Added In Between")
    func testAStaleWholeDocumentSaveDropsAFavouriteAddedInBetween() async throws {
        // Stored with a non-default hour, so the wait below is only satisfied once the listener has
        // emitted — the manager's fallback document would match an "empty favourites" wait from
        // the start.
        var stored = FoodLogSettings(authorId: "user-1")
        stored.endHour = 22
        let manager = TestManagers.foodLogSettingsManager(stored: stored)
        try await manager.signIn(userId: "user-1", isNewUser: false)
        #expect(await TestManagers.eventually { manager.foodLogSettings.endHour == 22 })

        // A settings screen takes its copy of the document.
        var settingsScreenCopy = manager.foodLogSettings

        // The nutrition tab favourites a food while that screen is open.
        var withFavourite = manager.foodLogSettings
        withFavourite.favouriteFoodIds = ["food-1"]
        try await manager.saveSettings(withFavourite)
        #expect(await TestManagers.eventually { manager.foodLogSettings.favouriteFoodIds == ["food-1"] })

        // The settings screen now writes its copy back.
        settingsScreenCopy.startHour = 5
        try await manager.saveSettings(settingsScreenCopy)

        #expect(await TestManagers.eventually { manager.foodLogSettings.startHour == 5 })
        #expect(manager.foodLogSettings.favouriteFoodIds.isEmpty)
    }

    /// The same shape between two settings screens, which is how the toggles on seven screens can
    /// undo one another.
    @Test("Test Two Settings Screens Writing Whole Documents Do Not Merge")
    func testTwoSettingsScreensWritingWholeDocumentsDoNotMerge() async throws {
        var stored = FoodLogSettings(authorId: "user-1")
        stored.endHour = 22
        let manager = TestManagers.foodLogSettingsManager(stored: stored)
        try await manager.signIn(userId: "user-1", isNewUser: false)
        #expect(await TestManagers.eventually { manager.foodLogSettings.endHour == 22 })

        var loggerBannerCopy = manager.foodLogSettings
        var optimisationCopy = manager.foodLogSettings

        loggerBannerCopy.showProteinRing = false
        try await manager.saveSettings(loggerBannerCopy)
        #expect(await TestManagers.eventually { manager.foodLogSettings.showProteinRing == false })

        optimisationCopy.quickAddEnabled = true
        try await manager.saveSettings(optimisationCopy)

        #expect(await TestManagers.eventually { manager.foodLogSettings.quickAddEnabled })
        // The ring is back on: the second screen's copy predates the first screen's save.
        #expect(manager.foodLogSettings.showProteinRing)
    }
}
