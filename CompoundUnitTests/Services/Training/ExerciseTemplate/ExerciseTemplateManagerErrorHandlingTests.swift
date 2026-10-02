//
//  ExerciseTemplateManagerErrorHandlingTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 28/10/2025.
//

import Testing
import Foundation
@testable import Compound

/// What the manager does when a write cannot be made. It used to wrap a services struct that could
/// be told to fail any call; it now writes through a sync engine, which fails only where the remote
/// genuinely can — on a document that is not there.
@MainActor
struct ExerciseModelManagerErrorTests {

    @Test("Test Deleting An Exercise That Does Not Exist Throws")
    func testDeletingAnExerciseThatDoesNotExistThrows() async {
        let manager = TestManagers.exerciseModelManager()
        await manager.signIn(userId: "author-1")

        await #expect(throws: (any Error).self) {
            try await manager.deleteExerciseModel(exerciseId: "non-existent-id")
        }
    }

    /// The user's library is untouched by a failed delete, rather than losing the exercise locally
    /// and keeping it remotely.
    @Test("Test A Failed Delete Leaves The Library Alone")
    func testAFailedDeleteLeavesTheLibraryAlone() async {
        let manager = TestManagers.exerciseModelManager(user: ExerciseModel.userMocks)
        await manager.signIn(userId: "mock_user_123")
        let before = manager.userExercises.count

        try? await manager.deleteExerciseModel(exerciseId: "non-existent-id")

        #expect(manager.userExercises.count == before)
    }
}
