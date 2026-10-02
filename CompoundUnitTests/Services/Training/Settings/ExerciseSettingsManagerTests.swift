//
//  ExerciseSettingsManagerTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 22/09/2026.
//

import Testing
import Foundation
@testable import Compound

/// One document per exercise, holding the two things a user can pin to it: a note and a rest
/// override. Both setters are read-modify-write over the whole document, so the behaviour that
/// matters is whether setting one of them keeps the other.
@MainActor
struct ExerciseSettingsManagerTests {

    private func settings(id: String, note: String? = nil, rest: Int? = nil) -> ExerciseSettingsModel {
        var model = ExerciseSettingsModel(id: id, authorId: "author-1")
        model.note = note
        model.restDurationOverride = rest
        return model
    }

    // MARK: - Reading

    @Test("Test Settings Are Empty Until Signed In")
    func testSettingsAreEmptyUntilSignedIn() {
        // The remote already has this document; the engine holds nothing until it listens.
        let manager = TestManagers.exerciseSettingsManager(settings: [settings(id: "bench", note: "Elbows in")])

        #expect(manager.allExerciseSettings.isEmpty)
        #expect(manager.note(for: "bench") == nil)
    }

    @Test("Test Signing In Loads The Saved Settings")
    func testSigningInLoadsTheSavedSettings() async {
        let manager = await TestManagers.signedInExerciseSettingsManager(
            settings: [settings(id: "bench", note: "Elbows in", rest: 180)]
        )

        #expect(manager.note(for: "bench") == "Elbows in")
        #expect(manager.restOverride(for: "bench") == 180)
    }

    @Test("Test An Exercise With No Settings Reads As Nothing Set")
    func testAnExerciseWithNoSettingsReadsAsNothingSet() async {
        let manager = await TestManagers.signedInExerciseSettingsManager()

        #expect(manager.settings(for: "bench") == nil)
        #expect(manager.note(for: "bench") == nil)
        #expect(manager.restOverride(for: "bench") == nil)
    }

    /// A note the user emptied is the same as no note — the screen shows a placeholder either
    /// way, and an empty string would otherwise read as a note that exists.
    @Test("Test An Empty Note Reads As No Note")
    func testAnEmptyNoteReadsAsNoNote() async {
        let manager = await TestManagers.signedInExerciseSettingsManager(
            settings: [settings(id: "bench", note: "")]
        )

        #expect(manager.note(for: "bench") == nil)
    }

    // MARK: - Writing

    @Test("Test Setting A Note On An Exercise With No Settings Creates The Document")
    func testSettingANoteCreatesTheDocument() async throws {
        let manager = await TestManagers.signedInExerciseSettingsManager(userId: "author-1")

        try await manager.setNote("Pause on the chest", for: "bench")

        let saved = await TestManagers.eventually { manager.note(for: "bench") == "Pause on the chest" }
        #expect(saved)
        // The document is the user's, and is filed under the exercise it belongs to.
        #expect(manager.settings(for: "bench")?.authorId == "author-1")
        #expect(manager.settings(for: "bench")?.id == "bench")
    }

    @Test("Test Clearing A Note Removes It")
    func testClearingANoteRemovesIt() async throws {
        let manager = await TestManagers.signedInExerciseSettingsManager(
            settings: [settings(id: "bench", note: "Elbows in")]
        )

        try await manager.setNote("", for: "bench")

        let cleared = await TestManagers.eventually { manager.note(for: "bench") == nil }
        #expect(cleared)
    }

    @Test("Test Setting A Rest Override Keeps The Note")
    func testSettingARestOverrideKeepsTheNote() async throws {
        let manager = await TestManagers.signedInExerciseSettingsManager(
            settings: [settings(id: "bench", note: "Elbows in")]
        )

        try await manager.setRestOverride(240, for: "bench")

        let saved = await TestManagers.eventually { manager.restOverride(for: "bench") == 240 }
        #expect(saved)
        #expect(manager.note(for: "bench") == "Elbows in")
    }

    @Test("Test Clearing A Rest Override Keeps The Note")
    func testClearingARestOverrideKeepsTheNote() async throws {
        let manager = await TestManagers.signedInExerciseSettingsManager(
            settings: [settings(id: "bench", note: "Elbows in", rest: 240)]
        )

        try await manager.setRestOverride(nil, for: "bench")

        let cleared = await TestManagers.eventually { manager.restOverride(for: "bench") == nil }
        #expect(cleared)
        #expect(manager.note(for: "bench") == "Elbows in")
    }

    /// Two edits to the same exercise, each waiting for the first to land. Both survive, because
    /// the second read-modify-write starts from a document the listener has already updated.
    ///
    /// The unguarded case is the same pair without the wait: the manager rebuilds the document
    /// from `allExerciseSettings`, which the listener has not caught up to yet, so the second
    /// write carries the pre-edit value of the first field. See the file's note in the report —
    /// the manager has no merge-on-write to defend it.
    @Test("Test A Note And A Rest Override Set In Turn Both Survive")
    func testANoteAndARestOverrideSetInTurnBothSurvive() async throws {
        let manager = await TestManagers.signedInExerciseSettingsManager()

        try await manager.setNote("Pause on the chest", for: "bench")
        let noteLanded = await TestManagers.eventually { manager.note(for: "bench") != nil }
        #expect(noteLanded)

        try await manager.setRestOverride(240, for: "bench")

        let both = await TestManagers.eventually {
            manager.note(for: "bench") == "Pause on the chest" && manager.restOverride(for: "bench") == 240
        }
        #expect(both)
    }

    @Test("Test Settings Are Per Exercise")
    func testSettingsArePerExercise() async throws {
        let manager = await TestManagers.signedInExerciseSettingsManager(
            settings: [settings(id: "bench", note: "Elbows in")]
        )

        try await manager.setNote("Chin over the bar", for: "pullup")

        let saved = await TestManagers.eventually { manager.note(for: "pullup") == "Chin over the bar" }
        #expect(saved)
        #expect(manager.note(for: "bench") == "Elbows in")
    }

    // MARK: - Signing out

    @Test("Test Signing Out Drops The Settings")
    func testSigningOutDropsTheSettings() async {
        let manager = await TestManagers.signedInExerciseSettingsManager(
            settings: [settings(id: "bench", note: "Elbows in")]
        )
        #expect(manager.note(for: "bench") == "Elbows in")

        manager.signOut()

        #expect(manager.allExerciseSettings.isEmpty)
    }
}
