//
//  GoalManager.swift
//  Compound
//
//  Created by Andrew Coyle on 20/10/2025.
//

import Foundation

@Observable
@MainActor
class GoalManager {
    
    private let userGoalSyncEngine: DocumentSyncEngine<WeightGoal>
    /// Signed in and listening, so a saved goal is followed; a save before sign-in is not.
    private var isListening = false
    
    var currentGoal: WeightGoal? {
        userGoalSyncEngine.currentDocument
    }
    
    init(userGoalSyncEngine: DocumentSyncEngine<WeightGoal>) {
        self.userGoalSyncEngine = userGoalSyncEngine
    }
    
    // MARK: - Public Methods
    
    /// Listens to the goal the user's `currentGoalId` names; accounts from before goals had their
    /// own documents have theirs under the user id.
    func signIn(userId: String, goalId: String? = nil) async throws {
        try await userGoalSyncEngine.startListening(documentId: goalId ?? userId)
        isListening = true
    }
    
    func signOut() {
        userGoalSyncEngine.stopListening()
        isListening = false
    }
    
    /// Saves a goal and follows it. A different goal from the current one is a new document —
    /// the rules refuse rewriting a goal's figures, which is why setting a second goal used to
    /// fail — so the listener moves to it and the one it replaces is marked abandoned, the only
    /// change the rules allow to a written goal.
    func saveGoal(_ goal: WeightGoal) async throws {
        let replaced = currentGoal
        try await userGoalSyncEngine.saveDocument(goal)
        // Followed even with nothing replaced: a first goal has its own id too, and the listener
        // started on the user id, where accounts from before goal ids kept theirs.
        if isListening {
            try await userGoalSyncEngine.startListening(documentId: goal.id)
        }
        guard let replaced, replaced.id != goal.id else { return }
        if replaced.status == .active {
            // Best effort: the new goal stands either way.
            try? await userGoalSyncEngine.updateDocument(
                id: replaced.id,
                data: [WeightGoal.CodingKeys.status.rawValue: WeightGoal.GoalStatus.abandoned.rawValue]
            )
        }
    }
    
    /// Edits the current goal's objective, target and weekly rate. Where it started stays: a fresh
    /// start is `saveGoal` with a new goal.
    ///
    /// A merge-save of the whole goal rather than a field update: `objective` is a Codable enum,
    /// which only the document encoder writes in its stored shape. The unchanged start and date
    /// make no diff, so the rules' freeze on them holds.
    @discardableResult
    func updateGoal(objective: OverarchingObjective, targetWeightKg: Double, weeklyChangeKg: Double) async throws -> WeightGoal {
        guard let goal = currentGoal else { throw GoalError.noCurrentGoal }
        let edited = WeightGoal(
            userId: goal.userId,
            objective: objective,
            startingWeightKg: goal.startingWeightKg,
            targetWeightKg: targetWeightKg,
            weeklyChangeKg: weeklyChangeKg,
            createdAt: goal.createdAt,
            status: goal.status,
            completedAt: goal.completedAt,
            id: goal.id
        )
        try await userGoalSyncEngine.saveDocument(edited)
        return edited
    }

    enum GoalError: LocalizedError {
        case noCurrentGoal
        var errorDescription: String? { String(localized: "There's no goal to edit.") }
    }

    /// Mark a goal as completed
    func completeGoal() async throws {
        try await self.updateGoalStatus(.completed)
    }
    
    /// Mark a goal as abandoned
    func abandonGoal() async throws {
        try await self.updateGoalStatus(.abandoned)
    }
        
    /// Pause a goal
    func pauseGoal() async throws {
        try await self.updateGoalStatus(.paused)
    }
    
    /// Resume a goal
    func resumeGoal() async throws {
        try await self.updateGoalStatus(.active)
    }
    
    private func updateGoalStatus(_ status: WeightGoal.GoalStatus) async throws {
        try await userGoalSyncEngine.updateDocument(
            data: [
                WeightGoal.CodingKeys.status.rawValue: status.rawValue
            ]
        )
    }
}

extension CoreInteractor {
    
    // MARK: GoalManager
    
    var currentGoal: WeightGoal? {
        goalManager.currentGoal
    }
        
    func saveGoal(_ goal: WeightGoal) async throws {
        try await goalManager.saveGoal(goal)
    }
        
    @discardableResult
    func updateGoal(objective: OverarchingObjective, targetWeightKg: Double, weeklyChangeKg: Double) async throws -> WeightGoal {
        try await goalManager.updateGoal(objective: objective, targetWeightKg: targetWeightKg, weeklyChangeKg: weeklyChangeKg)
    }

    func completeGoal() async throws {
        try await goalManager.completeGoal()
    }
    
    func abandonGoal() async throws {
        try await goalManager.abandonGoal()
    }
    
    func pauseGoal() async throws {
        try await goalManager.pauseGoal()
    }

    func resumeGoal() async throws {
        try await goalManager.resumeGoal()
    }
}
