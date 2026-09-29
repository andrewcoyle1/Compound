//
//  GoalManagerTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 22/09/2026.
//

import Testing
import Foundation
@testable import DialedIn

/// The user's single weight goal.
///
/// `WeightGoal.id` is the user id, so there is exactly one goal per account and saving is always
/// an overwrite. Everything the app shows about progress — the target, the weekly rate, whether
/// the goal is still running — comes off `currentGoal`, which is nil until the document listener
/// has emitted.
///
/// The four status transitions send a field update rather than a whole document, and
/// `MockRemoteDocumentService.updateDocument` re-yields the stored document without applying the
/// fields. So a test can prove a transition reached the store and can prove the guard paths, but
/// cannot observe `status` changing; that needs a fake that applies writes, which would mean
/// importing SwiftfulDataManagers into the test target. The transition tests below say only what
/// they can actually check.
@MainActor
struct GoalManagerTests {

    private let userId = "user-1"

    private func goal(
        objective: OverarchingObjective = .loseWeight,
        startingWeightKg: Double = 82,
        targetWeightKg: Double = 75,
        weeklyChangeKg: Double = 0.5,
        status: WeightGoal.GoalStatus = .active
    ) -> WeightGoal {
        WeightGoal(
            userId: userId,
            objective: objective,
            startingWeightKg: startingWeightKg,
            targetWeightKg: targetWeightKg,
            weeklyChangeKg: weeklyChangeKg,
            status: status
        )
    }

    // MARK: - Reading

    @Test("Test The Goal Is Nil Until Signed In")
    func testTheGoalIsNilUntilSignedIn() {
        #expect(TestManagers.goalManager(goal: goal()).currentGoal == nil)
    }

    @Test("Test Signing In Exposes The Stored Goal")
    func testSigningInExposesTheStoredGoal() async throws {
        let stored = goal()
        let manager = try await TestManagers.signedInGoalManager(goal: stored)

        let current = try #require(manager.currentGoal)
        #expect(current == stored)
        #expect(current.status == .active)
    }

    /// Most accounts have never set a goal, and the screens behind `currentGoal` show their empty
    /// state off nil rather than off a placeholder goal.
    @Test("Test Signing In With No Stored Goal Leaves It Nil")
    func testSigningInWithNoStoredGoalLeavesItNil() async throws {
        let manager = try await TestManagers.signedInGoalManager(goal: nil)

        #expect(manager.currentGoal == nil)
    }

    @Test("Test Signing Out Clears The Goal")
    func testSigningOutClearsTheGoal() async throws {
        let manager = try await TestManagers.signedInGoalManager(goal: goal())
        #expect(manager.currentGoal != nil)

        manager.signOut()

        // One account's target must not still be on screen after another signs in.
        #expect(manager.currentGoal == nil)
    }

    // MARK: - Writing

    @Test("Test Saving A Goal Makes It Current")
    func testSavingAGoalMakesItCurrent() async throws {
        let manager = try await TestManagers.signedInGoalManager(goal: nil)

        try await manager.saveGoal(goal(targetWeightKg: 70))

        #expect(await TestManagers.eventually { manager.currentGoal != nil })
        #expect(manager.currentGoal?.targetWeightKg == 70)
    }

    /// There is one goal per user id, so saving a second one has to replace the first rather than
    /// leave two documents that the app would then have to choose between.
    @Test("Test Saving Over An Existing Goal Replaces It")
    func testSavingOverAnExistingGoalReplacesIt() async throws {
        let manager = try await TestManagers.signedInGoalManager(goal: goal(targetWeightKg: 75))

        try await manager.saveGoal(goal(objective: .gainWeight, startingWeightKg: 82, targetWeightKg: 90))

        #expect(await TestManagers.eventually { manager.currentGoal?.targetWeightKg == 90 })
        let current = try #require(manager.currentGoal)
        #expect(current.objective == .gainWeight)
        #expect(current.id == userId)
    }

    /// The save itself is a plain remote write and does not fail when nobody is listening, but
    /// nothing on screen updates from it. Onboarding saves the goal after sign-in for that reason.
    @Test("Test Saving A Goal Before Signing In Does Not Make It Current")
    func testSavingAGoalBeforeSigningInDoesNotMakeItCurrent() async throws {
        let manager = TestManagers.goalManager()

        try await manager.saveGoal(goal())

        #expect(manager.currentGoal == nil)
    }

    // MARK: - Status transitions

    /// Each of the four transitions writes `status` on the stored document. The mock remote does
    /// not apply field writes, so this checks the call reaches the store and resolves an id —
    /// which is what breaks when the goal's id and the signed-in id drift apart — not the value.
    @Test("Test Every Status Transition Reaches The Stored Goal")
    func testEveryStatusTransitionReachesTheStoredGoal() async throws {
        let manager = try await TestManagers.signedInGoalManager(goal: goal())

        try await manager.completeGoal()
        try await manager.abandonGoal()
        try await manager.pauseGoal()
        try await manager.resumeGoal()

        #expect(manager.currentGoal != nil)
    }

    /// Without a document id there is nothing to update, and a transition that quietly did nothing
    /// would leave a goal the user thinks they finished still running.
    @Test("Test Status Transitions Throw Before Signing In")
    func testStatusTransitionsThrowBeforeSigningIn() async {
        let manager = TestManagers.goalManager(goal: goal())

        await #expect(throws: (any Error).self) { try await manager.completeGoal() }
        await #expect(throws: (any Error).self) { try await manager.abandonGoal() }
        await #expect(throws: (any Error).self) { try await manager.pauseGoal() }
        await #expect(throws: (any Error).self) { try await manager.resumeGoal() }
    }

    @Test("Test Status Transitions Throw When There Is No Goal To Change")
    func testStatusTransitionsThrowWhenThereIsNoGoalToChange() async throws {
        let manager = try await TestManagers.signedInGoalManager(goal: nil)

        await #expect(throws: (any Error).self) { try await manager.completeGoal() }
        await #expect(throws: (any Error).self) { try await manager.pauseGoal() }
    }
}
