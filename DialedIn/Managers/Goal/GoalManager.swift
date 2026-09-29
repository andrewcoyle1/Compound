//
//  GoalManager.swift
//  DialedIn
//
//  Created by Andrew Coyle on 20/10/2025.
//

import Foundation

@Observable
@MainActor
class GoalManager {
    
    private let userGoalSyncEngine: DocumentSyncEngine<WeightGoal>
    
    var currentGoal: WeightGoal? {
        userGoalSyncEngine.currentDocument
    }
    
    init(userGoalSyncEngine: DocumentSyncEngine<WeightGoal>) {
        self.userGoalSyncEngine = userGoalSyncEngine
    }
    
    // MARK: - Public Methods
    
    func signIn(userId id: String) async throws {
        try await userGoalSyncEngine.startListening(documentId: id)
    }
    
    func signOut() {
        userGoalSyncEngine.stopListening()
    }
    
    func saveGoal(_ goal: WeightGoal) async throws {
        try await userGoalSyncEngine.saveDocument(goal)
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
