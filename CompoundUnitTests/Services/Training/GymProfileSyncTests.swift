//
//  GymProfileSyncTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 28/10/2025.
//

import Testing
import Foundation
@testable import Compound

/// What the manager does with the gym profiles it holds.
///
/// This file used to test reconciliation between a local store and Firestore — last write wins,
/// tombstones propagating both ways — against a hand-written `LocalGymProfilePersistence` and
/// `RemoteGymProfileService`. Both are gone: the manager now wraps a `CollectionSyncEngine`, and
/// the merge rules those tests covered belong to SwiftfulDataManagers, where they are tested. The
/// SwiftData entity-identity tests that lived alongside them went with `GymProfileEntity`.
@MainActor
struct GymProfileSyncTests {

    private func profile(id: String, authorId: String = "author-1", name: String) -> GymProfileModel {
        GymProfileModel(id: id, authorId: authorId, name: name)
    }

    @Test("Test Profiles Are Empty Until Signed In")
    func testProfilesAreEmptyUntilSignedIn() {
        let manager = TestManagers.gymProfileManager(profiles: [profile(id: "gym-1", name: "Home")])

        #expect(manager.gymProfiles.isEmpty)
    }

    @Test("Test Signing In Loads The Author's Profiles")
    func testSigningInLoadsTheAuthorsProfiles() async {
        let manager = TestManagers.gymProfileManager(profiles: [
            profile(id: "gym-1", name: "Home"),
            profile(id: "gym-2", name: "Commercial")
        ])

        await manager.signIn()

        #expect(manager.gymProfiles.count == 2)
    }

    @Test("Test Saving A Profile Adds It")
    func testSavingAProfileAddsIt() async throws {
        let manager = TestManagers.gymProfileManager()
        await manager.signIn()

        try await manager.saveGymProfile(profile: profile(id: "gym-1", name: "Home"), image: nil)

        let added = await TestManagers.eventually { manager.gymProfiles.map(\.id) == ["gym-1"] }
        #expect(added)
    }

    @Test("Test Saving An Existing Profile Replaces It")
    func testSavingAnExistingProfileReplacesIt() async throws {
        let manager = TestManagers.gymProfileManager(profiles: [profile(id: "gym-1", name: "Home")])
        await manager.signIn()

        try await manager.saveGymProfile(profile: profile(id: "gym-1", name: "Renamed"), image: nil)

        let renamed = await TestManagers.eventually { manager.gymProfiles.first?.name == "Renamed" }
        #expect(renamed)
        #expect(manager.gymProfiles.count == 1)
    }

    @Test("Test Reading A Profile By Id")
    func testReadingAProfileById() async throws {
        let manager = TestManagers.gymProfileManager(profiles: [profile(id: "gym-1", name: "Home")])
        await manager.signIn()

        let found = try await manager.getGymProfile(gymProfileId: "gym-1")

        #expect(found.name == "Home")
    }

    @Test("Test Reading A Profile That Does Not Exist Throws")
    func testReadingAProfileThatDoesNotExistThrows() async {
        let manager = TestManagers.gymProfileManager()
        await manager.signIn()

        await #expect(throws: (any Error).self) {
            _ = try await manager.getGymProfile(gymProfileId: "missing")
        }
    }

    @Test("Test Deleting A Profile Removes It")
    func testDeletingAProfileRemovesIt() async throws {
        let manager = TestManagers.gymProfileManager(profiles: [
            profile(id: "gym-1", name: "Home"),
            profile(id: "gym-2", name: "Commercial")
        ])
        await manager.signIn()

        try await manager.deleteGymProfile("gym-1")

        let removed = await TestManagers.eventually { manager.gymProfiles.map(\.id) == ["gym-2"] }
        #expect(removed)
    }

    @Test("Test Deleting All Profiles Empties The List")
    func testDeletingAllProfilesEmptiesTheList() async throws {
        let manager = TestManagers.gymProfileManager(profiles: [
            profile(id: "gym-1", name: "Home"),
            profile(id: "gym-2", name: "Commercial")
        ])
        await manager.signIn()

        try await manager.deleteAllGymProfiles()

        let emptied = await TestManagers.eventually { manager.gymProfiles.isEmpty }
        #expect(emptied)
    }

    @Test("Test The Active Workout Profile Is Held Separately")
    func testTheActiveWorkoutProfileIsHeldSeparately() async {
        let manager = TestManagers.gymProfileManager(profiles: [profile(id: "gym-1", name: "Home")])
        await manager.signIn()
        #expect(manager.activeWorkoutGymProfile == nil)

        manager.activeWorkoutGymProfile = manager.gymProfiles.first

        #expect(manager.activeWorkoutGymProfile?.id == "gym-1")
    }
}
