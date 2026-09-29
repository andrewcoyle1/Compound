//
//  WorkoutTemplateManagerTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 22/09/2026.
//

import Testing
import Foundation
@testable import DialedIn

/// The workout library, which is two libraries: the templates shipped with the app, seeded into
/// local persistence, and the user's own, synced from Firestore. Only the second is ever written
/// to from a screen, and only the first can be rebuilt — so what is worth pinning is that seeding
/// and deleting each stay on their own side of that line.
@MainActor
struct WorkoutTemplateManagerTests {

    private func template(id: String, name: String, authorId: String = "author-1") -> WorkoutTemplateModel {
        WorkoutTemplateModel(id: id, authorId: authorId, name: name, exercises: [])
    }

    // MARK: - The two libraries

    @Test("Test User Templates Are Empty Until Signed In")
    func testUserTemplatesAreEmptyUntilSignedIn() {
        // The sync engine holds nothing until it listens, so the user's library is empty even
        // though the remote already has templates for them.
        let manager = TestManagers.workoutTemplateManager(user: [template(id: "w1", name: "Push")])

        #expect(manager.userWorkoutTemplates.isEmpty)
    }

    @Test("Test Signing In Loads The User's Own Templates")
    func testSigningInLoadsTheUsersOwnTemplates() async {
        let manager = await TestManagers.signedInWorkoutTemplateManager(
            user: [template(id: "w1", name: "Push"), template(id: "w2", name: "Pull")]
        )

        #expect(manager.userWorkoutTemplates.map(\.id).sorted() == ["w1", "w2"])
    }

    /// The seeded library is local, so it reads without a sign-in — this is what a signed-out
    /// screen still has to show.
    @Test("Test Seeded Templates Read Without Signing In")
    func testSeededTemplatesReadWithoutSigningIn() {
        let manager = TestManagers.workoutTemplateManager(
            system: [template(id: "s1", name: "Full Body", authorId: "official")]
        )

        #expect(manager.systemWorkoutTemplates.map(\.id) == ["s1"])
        #expect(manager.allWorkoutTemplates.map(\.id) == ["s1"])
    }

    @Test("Test All Templates Joins Both Libraries With The Seeded Ones First")
    func testAllTemplatesJoinsBothLibraries() async {
        let manager = await TestManagers.signedInWorkoutTemplateManager(
            user: [template(id: "w1", name: "Mine")],
            system: [template(id: "s1", name: "Seeded", authorId: "official")]
        )

        #expect(manager.allWorkoutTemplates.map(\.id) == ["s1", "w1"])
    }

    // MARK: - Writing

    @Test("Test Saving A Template Adds It To The User's Library")
    func testSavingATemplateAddsItToTheUsersLibrary() async throws {
        let manager = await TestManagers.signedInWorkoutTemplateManager()

        try await manager.saveWorkoutTemplate(template(id: "new-1", name: "Legs"), nil)

        let added = await TestManagers.eventually { manager.userWorkoutTemplates.map(\.id) == ["new-1"] }
        #expect(added)
    }

    @Test("Test Saving An Existing Template Replaces It Rather Than Duplicating It")
    func testSavingAnExistingTemplateReplacesIt() async throws {
        let manager = await TestManagers.signedInWorkoutTemplateManager(
            user: [template(id: "w1", name: "Push")]
        )

        try await manager.saveWorkoutTemplate(template(id: "w1", name: "Push Day A"), nil)

        let renamed = await TestManagers.eventually {
            manager.userWorkoutTemplates.count == 1 && manager.userWorkoutTemplates.first?.name == "Push Day A"
        }
        #expect(renamed)
    }

    @Test("Test Reading A Template By Id")
    func testReadingATemplateById() async {
        let manager = await TestManagers.signedInWorkoutTemplateManager(
            user: [template(id: "w1", name: "Push")],
            system: [template(id: "s1", name: "Seeded", authorId: "official")]
        )

        #expect(manager.getWorkoutTemplate(id: "w1")?.name == "Push")
        // The synchronous read only sees the synced library — a seeded template is not in it.
        //
        // getWorkoutTemplate(id:) is overloaded: a sync one returning an optional, and an
        // `async throws` one returning non-optional. Inside an async body Swift prefers the
        // async overload, and annotating the *result* does not help, because the non-optional
        // return converts implicitly to the optional and so both stay viable. Pinning the
        // function's type is what actually selects the sync overload.
        let readTemplate = manager.getWorkoutTemplate(id:) as (String) -> WorkoutTemplateModel?
        #expect(readTemplate("s1") == nil)
        #expect(readTemplate("nope") == nil)
    }

    @Test("Test Deleting A Template Removes It From The User's Library")
    func testDeletingATemplateRemovesIt() async throws {
        let manager = await TestManagers.signedInWorkoutTemplateManager(
            user: [template(id: "w1", name: "Push"), template(id: "w2", name: "Pull")]
        )

        try await manager.deleteWorkoutTemplate(id: "w1")

        let removed = await TestManagers.eventually { manager.userWorkoutTemplates.map(\.id) == ["w2"] }
        #expect(removed)
    }

    @Test("Test Signing Out Empties The User's Library")
    func testSigningOutEmptiesTheUsersLibrary() async {
        let manager = await TestManagers.signedInWorkoutTemplateManager(
            user: [template(id: "w1", name: "Push")],
            system: [template(id: "s1", name: "Seeded", authorId: "official")]
        )
        #expect(manager.userWorkoutTemplates.count == 1)

        manager.signOut()

        #expect(manager.userWorkoutTemplates.isEmpty)
        // The seeded library belongs to the install rather than the account, so it stays.
        #expect(manager.systemWorkoutTemplates.map(\.id) == ["s1"])
    }
}
