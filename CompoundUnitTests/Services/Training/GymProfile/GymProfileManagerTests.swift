//
//  GymProfileManagerTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 22/09/2026.
//

import Testing
import Foundation
@testable import Compound

/// The gyms the user trains at, and the equipment each one has.
///
/// Every exercise the app offers during a workout is filtered by the active gym's equipment, so a
/// profile that loses its equipment lists silently narrows what the user can log. `GymProfileSyncTests`
/// covers loading, saving, reading by id and deleting; this suite covers what that one leaves —
/// the session boundary, the failure paths, the equipment payload and the stored form.
///
/// `saveGymProfile(profile:image:)` builds a `FirebaseImageUploadService` inline, so only the
/// `image: nil` path is reachable from a unit test. Every save here passes nil.
@MainActor
struct GymProfileManagerTests {

    private func profile(
        id: String,
        authorId: String = "author-1",
        name: String,
        imageUrl: String? = nil
    ) -> GymProfileModel {
        GymProfileModel(id: id, authorId: authorId, name: name, imageUrl: imageUrl)
    }

    private var twoProfiles: [GymProfileModel] {
        [profile(id: "gym-1", name: "Home"), profile(id: "gym-2", name: "Commercial")]
    }

    // MARK: - Session boundary

    @Test("Test Signing Out Clears The Profiles")
    func testSigningOutClearsTheProfiles() async {
        let manager = await TestManagers.signedInGymProfileManager(profiles: twoProfiles)
        #expect(manager.gymProfiles.count == 2)

        manager.signOut()

        // One account's gyms must not still be selectable after another signs in.
        #expect(manager.gymProfiles.isEmpty)
    }

    @Test("Test Signing In Again Restores The Profiles")
    func testSigningInAgainRestoresTheProfiles() async {
        let manager = await TestManagers.signedInGymProfileManager(profiles: twoProfiles)
        manager.signOut()

        await manager.signIn()

        #expect(await TestManagers.eventually { manager.gymProfiles.count == 2 })
    }

    /// The active gym is held on the manager rather than in the sync engine, so stopping the
    /// listener does not clear it on its own. It has to be cleared explicitly, or the next account
    /// to sign in reads the previous one's gym through `CoreInteractor.workoutGymProfile`.
    @Test("Test Signing Out Clears The Active Workout Profile")
    func testSigningOutClearsTheActiveWorkoutProfile() async {
        let manager = await TestManagers.signedInGymProfileManager(profiles: twoProfiles)
        manager.activeWorkoutGymProfile = manager.gymProfiles.first

        manager.signOut()

        #expect(manager.gymProfiles.isEmpty)
        #expect(manager.activeWorkoutGymProfile == nil)
    }

    /// Reading by id goes to the store when the collection has not been loaded, so a deep link into
    /// a gym does not have to wait on the listener first.
    @Test("Test Reading A Profile Before Signing In Fetches It From The Store")
    func testReadingAProfileBeforeSigningInFetchesItFromTheStore() async throws {
        let manager = TestManagers.gymProfileManager(profiles: twoProfiles)
        #expect(manager.gymProfiles.isEmpty)

        let found = try await manager.getGymProfile(gymProfileId: "gym-2")

        #expect(found.name == "Commercial")
    }

    // MARK: - Writing

    /// A save with no new image must leave the existing one alone: the image is only replaced when
    /// one is passed, and renaming a gym from the edit screen sends `image: nil`.
    @Test("Test Saving Without An Image Keeps The Existing Image Url")
    func testSavingWithoutAnImageKeepsTheExistingImageUrl() async throws {
        let existing = profile(id: "gym-1", name: "Home", imageUrl: "https://example.com/gym.jpg")
        let manager = await TestManagers.signedInGymProfileManager(profiles: [existing])

        var renamed = existing
        renamed.name = "Home Garage"
        try await manager.saveGymProfile(profile: renamed, image: nil)

        #expect(await TestManagers.eventually { manager.gymProfiles.first?.name == "Home Garage" })
        #expect(manager.gymProfiles.first?.imageUrl == "https://example.com/gym.jpg")
    }

    /// The equipment lists are the whole point of a gym profile. An empty list is a real answer —
    /// "this gym has no free weights" — and has to survive the round trip as an empty list rather
    /// than falling back to the default catalog.
    @Test("Test A Profile's Equipment Selection Survives Saving")
    func testAProfilesEquipmentSelectionSurvivesSaving() async throws {
        let manager = await TestManagers.signedInGymProfileManager(profiles: [])
        let bodyweightOnly = GymProfileModel(
            id: "gym-3",
            authorId: "author-1",
            name: "Hotel Room",
            freeWeights: [],
            loadableBars: [],
            fixedWeightBars: [],
            cableMachines: [],
            plateLoadedMachines: [],
            pinLoadedMachines: []
        )

        try await manager.saveGymProfile(profile: bodyweightOnly, image: nil)

        #expect(await TestManagers.eventually { manager.gymProfiles.count == 1 })
        let saved = try #require(manager.gymProfiles.first)
        #expect(saved.freeWeights.isEmpty)
        #expect(saved.cableMachines.isEmpty)
        #expect(saved.pinLoadedMachines.isEmpty)
        // Untouched categories keep the defaults the profile was built with.
        #expect(saved.bodyWeights.count == BodyWeights.defaultBodyWeights.count)
        #expect(saved.bands.count == Bands.defaultBands.count)
    }

    // MARK: - Deleting

    /// Deleting a gym that is not there throws rather than passing silently, so a screen that
    /// deleted the same profile twice reports it instead of appearing to succeed.
    @Test("Test Deleting A Profile That Does Not Exist Throws")
    func testDeletingAProfileThatDoesNotExistThrows() async {
        let manager = await TestManagers.signedInGymProfileManager(profiles: twoProfiles)

        await #expect(throws: (any Error).self) {
            try await manager.deleteGymProfile("missing")
        }
        #expect(manager.gymProfiles.count == 2)
    }

    /// `deleteAllGymProfiles` runs during account deletion, where an account with no gyms is
    /// ordinary. It loops over what it holds, so there is nothing to fail on.
    @Test("Test Deleting All Profiles When There Are None Does Nothing")
    func testDeletingAllProfilesWhenThereAreNoneDoesNothing() async throws {
        let manager = await TestManagers.signedInGymProfileManager(profiles: [])

        try await manager.deleteAllGymProfiles()

        #expect(manager.gymProfiles.isEmpty)
    }

    /// A workout in progress filters exercises on the active gym's equipment, so a deleted gym
    /// left selected keeps filtering on equipment that is no longer there.
    @Test("Test Deleting The Active Profile Clears The Selection")
    func testDeletingTheActiveProfileClearsTheSelection() async throws {
        let manager = await TestManagers.signedInGymProfileManager(profiles: twoProfiles)
        manager.activeWorkoutGymProfile = manager.gymProfiles.first

        try await manager.deleteGymProfile("gym-1")

        #expect(await TestManagers.eventually { manager.gymProfiles.map(\.id) == ["gym-2"] })
        #expect(manager.activeWorkoutGymProfile == nil)
    }

    /// Deleting some other gym must not disturb the selection — only the one that went away.
    @Test("Test Deleting Another Profile Leaves The Selection Alone")
    func testDeletingAnotherProfileLeavesTheSelectionAlone() async throws {
        let manager = await TestManagers.signedInGymProfileManager(profiles: twoProfiles)
        manager.activeWorkoutGymProfile = manager.gymProfiles.first { $0.id == "gym-1" }

        try await manager.deleteGymProfile("gym-2")

        #expect(await TestManagers.eventually { manager.gymProfiles.map(\.id) == ["gym-1"] })
        #expect(manager.activeWorkoutGymProfile?.id == "gym-1")
    }

    // MARK: - Stored form

    /// The wire format, which the in-memory mock remote does not exercise. Every equipment list has
    /// its own snake_case key, and a key that stops matching reads back as a decode failure rather
    /// than as a gym with less equipment.
    @Test("Test A Profile Round Trips Through Its Stored Form")
    func testAProfileRoundTripsThroughItsStoredForm() throws {
        let original = GymProfileModel(
            id: "gym-1",
            authorId: "author-1",
            name: "Home",
            imageUrl: "https://example.com/gym.jpg",
            icon: "dumbbell",
            freeWeights: []
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GymProfileModel.self, from: encoded)

        #expect(decoded.id == "gym-1")
        #expect(decoded.authorId == "author-1")
        #expect(decoded.imageUrl == "https://example.com/gym.jpg")
        // An empty stored list gains the catalogue switched off, which is the merge on decode
        // (see `GymProfileDecodingTests`): items cannot be deleted, so nothing is brought back.
        #expect(decoded.freeWeights.map(\.id) == FreeWeights.defaultFreeWeights.map(\.id))
        #expect(decoded.freeWeights.allSatisfy { !$0.isActive })
        #expect(decoded.cableMachines.count == original.cableMachines.count)
        #expect(decoded.pinLoadedMachines.count == original.pinLoadedMachines.count)

        let object = try JSONSerialization.jsonObject(with: encoded)
        let json = try #require(object as? [String: Any])
        #expect(json["author_id"] as? String == "author-1")
        #expect(json["image_url"] as? String == "https://example.com/gym.jpg")
        #expect(json.keys.contains("pin_loaded_machines"))
    }
}
