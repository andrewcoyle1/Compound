//
//  WorkoutSettingsManagerTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 22/09/2026.
//

import Testing
import Foundation
@testable import DialedIn

/// One Firestore document holding every workout preference, written whole by a dozen screens.
///
/// Nothing here writes a field; each screen takes a copy of `workoutSettings`, changes one thing
/// and saves the lot. That makes two behaviours load-bearing: the manager must never hand out a
/// document the user did not save, and it must never create one over the top of one that exists.
@MainActor
struct WorkoutSettingsManagerTests {

    private func customised(authorId: String = "author-1") -> WorkoutSettings {
        var settings = WorkoutSettings(authorId: authorId)
        settings.rirTracking = true
        settings.defaultRestDurationSeconds = 150
        settings.useRestTimers = false
        settings.previousWorkoutReference = .workoutsInMesocycle
        return settings
    }

    // MARK: - Before signing in

    /// Every screen reads `workoutSettings` unconditionally, so it answers defaults rather than
    /// nothing — but those defaults are not a saved document and must not be written as one.
    @Test("Test Settings Are The Defaults Before Signing In")
    func testSettingsAreTheDefaultsBeforeSigningIn() {
        let manager = TestManagers.workoutSettingsManager(customised())

        #expect(manager.workoutSettings.authorId == "")
        #expect(manager.workoutSettings.rirTracking == false)
        #expect(manager.workoutSettings.defaultRestDurationSeconds == 90)
    }

    // MARK: - Signing in

    @Test("Test Signing In With No Document Saves The Defaults For This User")
    func testSigningInWithNoDocumentSavesTheDefaults() async throws {
        let manager = TestManagers.workoutSettingsManager(nil)

        try await manager.signIn(userId: "author-1", isNewUser: true)

        let created = await TestManagers.eventually { manager.workoutSettings.authorId == "author-1" }
        #expect(created)
        #expect(manager.workoutSettings.defaultRestDurationSeconds == 90)
    }

    /// The one that loses data. `startListening` returns before its listener has emitted, so the
    /// manager's own `currentDocument` is nil at that moment for everyone — a returning user
    /// included. Creating the defaults off that nil overwrites every setting they had saved,
    /// since the write is the whole document.
    @Test("Test Signing In Keeps Settings The User Already Saved")
    func testSigningInKeepsSettingsTheUserAlreadySaved() async throws {
        let manager = TestManagers.workoutSettingsManager(customised())

        try await manager.signIn(userId: "author-1", isNewUser: false)

        let loaded = await TestManagers.eventually { manager.workoutSettings.rirTracking }
        #expect(loaded)
        #expect(manager.workoutSettings.defaultRestDurationSeconds == 150)
        #expect(manager.workoutSettings.useRestTimers == false)
        #expect(manager.workoutSettings.previousWorkoutReference == .workoutsInMesocycle)
    }

    // MARK: - Saving

    @Test("Test Saving Settings Replaces What The Manager Hands Out")
    func testSavingSettingsReplacesWhatTheManagerHandsOut() async throws {
        let manager = TestManagers.workoutSettingsManager(nil)
        try await manager.signIn(userId: "author-1", isNewUser: true)

        try await manager.saveSettings(customised())

        let saved = await TestManagers.eventually { manager.workoutSettings.defaultRestDurationSeconds == 150 }
        #expect(saved)
        #expect(manager.workoutSettings.rirTracking)
    }

    /// What the eleven screens editing this document rely on: a save carries every field, so the
    /// settings a screen did not touch have to survive its write.
    @Test("Test Saving From A Fresh Read Keeps The Other Settings")
    func testSavingFromAFreshReadKeepsTheOtherSettings() async throws {
        let manager = TestManagers.workoutSettingsManager(customised())
        try await manager.signIn(userId: "author-1", isNewUser: false)
        _ = await TestManagers.eventually { manager.workoutSettings.rirTracking }

        // A screen's edit: read what is there now, change one thing, write it all back.
        var edited = manager.workoutSettings
        edited.showWorkoutTimer = false
        try await manager.saveSettings(edited)

        let applied = await TestManagers.eventually { manager.workoutSettings.showWorkoutTimer == false }
        #expect(applied)
        #expect(manager.workoutSettings.defaultRestDurationSeconds == 150)
        #expect(manager.workoutSettings.rirTracking)
    }

    /// And the failure mode that has no defence in the manager: a screen that saved a snapshot
    /// taken before a sibling's write puts every one of its own fields back. The manager writes
    /// documents whole, so the second save wins the whole document, not just its own field.
    @Test("Test A Stale Snapshot Overwrites A Setting Saved After It Was Taken")
    func testAStaleSnapshotOverwritesASettingSavedAfterItWasTaken() async throws {
        let manager = TestManagers.workoutSettingsManager(nil)
        try await manager.signIn(userId: "author-1", isNewUser: true)
        let stale = manager.workoutSettings

        var other = stale
        other.rirTracking = true
        try await manager.saveSettings(other)
        let sawFirst = await TestManagers.eventually { manager.workoutSettings.rirTracking }
        #expect(sawFirst)

        var fromStale = stale
        fromStale.showWorkoutTimer = false
        try await manager.saveSettings(fromStale)

        let applied = await TestManagers.eventually { manager.workoutSettings.showWorkoutTimer == false }
        #expect(applied)
        // Documented, not desired: the manager cannot tell a whole-document save from a merge, so
        // the RIR setting made between the read and the write is gone. The defence is at the
        // screens, which re-read before saving.
        #expect(manager.workoutSettings.rirTracking == false)
    }

    // MARK: - Signing out

    @Test("Test Signing Out Drops Back To The Defaults")
    func testSigningOutDropsBackToTheDefaults() async throws {
        let manager = TestManagers.workoutSettingsManager(customised())
        try await manager.signIn(userId: "author-1", isNewUser: false)
        _ = await TestManagers.eventually { manager.workoutSettings.rirTracking }

        manager.signOut()

        #expect(manager.workoutSettings.rirTracking == false)
        #expect(manager.workoutSettings.defaultRestDurationSeconds == 90)
    }
}
