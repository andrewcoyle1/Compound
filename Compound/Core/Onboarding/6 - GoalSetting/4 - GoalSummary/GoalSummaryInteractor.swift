//
//  GoalSummaryInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol GoalSummaryInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
    var currentWeightKilograms: Double? { get }
    func saveGoal(_ goal: WeightGoal
    ) async throws
    func updateCurrentGoalId(goalId: String?) async throws
    func updateGoal(objective: OverarchingObjective, targetWeightKg: Double, weeklyChangeKg: Double) async throws
}

extension CoreInteractor: GoalSummaryInteractor { }
