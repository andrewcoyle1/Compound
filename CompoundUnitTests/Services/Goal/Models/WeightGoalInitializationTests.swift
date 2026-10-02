//
//  WeightGoalInitializationTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 25/10/2025.
//

import Testing
import Foundation
@testable import Compound

@MainActor
struct WeightGoalInitializationTests {

    // MARK: - Initialization Tests
    
    @Test("Test Basic Initialisation")
    func testBasicInitialization() {
        let randomUserId = String.random
        let randomObjective = OverarchingObjective.loseWeight
        let randomStartingWeight = 75.0
        let randomTargetWeight = 68.0
        let randomWeeklyChange = 0.5
        
        let goal = WeightGoal(
            userId: randomUserId,
            objective: randomObjective,
            startingWeightKg: randomStartingWeight,
            targetWeightKg: randomTargetWeight,
            weeklyChangeKg: randomWeeklyChange
        )
        
        #expect(goal.userId == randomUserId)
        #expect(goal.objective == randomObjective)
        #expect(goal.startingWeightKg == randomStartingWeight)
        #expect(goal.targetWeightKg == randomTargetWeight)
        #expect(goal.weeklyChangeKg == randomWeeklyChange)
        #expect(goal.status == WeightGoal.GoalStatus.active)
        #expect(goal.completedAt == nil)
    }
    
    @Test("Test Initialization With All Properties")
    func testInitializationWithAllProperties() {
        let testData = createWeightGoalTestData()
        let goal = createWeightGoalWithAllProperties(data: testData)
        verifyWeightGoalProperties(goal: goal, data: testData)
    }
    
    private func createWeightGoalTestData() -> WeightGoalTestData {
        return WeightGoalTestData(
            userId: String.random,
            objective: .loseWeight,
            startingWeightKg: 75.0,
            targetWeightKg: 68.0,
            weeklyChangeKg: 0.5,
            createdAt: Date.random,
            status: .active,
            completedAt: nil
        )
    }
    
    private struct WeightGoalTestData {
        let userId: String
        let objective: OverarchingObjective
        let startingWeightKg: Double
        let targetWeightKg: Double
        let weeklyChangeKg: Double
        let createdAt: Date
        let status: WeightGoal.GoalStatus
        let completedAt: Date?
    }
    
    private func createWeightGoalWithAllProperties(data: WeightGoalTestData) -> WeightGoal {
        return WeightGoal(
            userId: data.userId,
            objective: data.objective,
            startingWeightKg: data.startingWeightKg,
            targetWeightKg: data.targetWeightKg,
            weeklyChangeKg: data.weeklyChangeKg,
            createdAt: data.createdAt,
            status: data.status,
            completedAt: data.completedAt
        )
    }
    
    private func verifyWeightGoalProperties(goal: WeightGoal, data: WeightGoalTestData) {
        #expect(goal.userId == data.userId)
        #expect(goal.objective == data.objective)
        #expect(goal.startingWeightKg == data.startingWeightKg)
        #expect(goal.targetWeightKg == data.targetWeightKg)
        #expect(goal.weeklyChangeKg == data.weeklyChangeKg)
        #expect(goal.createdAt == data.createdAt)
        #expect(goal.status == data.status)
        #expect(goal.completedAt == data.completedAt)
    }
    
    @Test("Test Initialization With Default Parameters")
    func testInitializationWithDefaultParameters() {
        let randomUserId = String.random
        let randomObjective = OverarchingObjective.gainWeight
        let randomStartingWeight = 65.0
        let randomTargetWeight = 70.0
        let randomWeeklyChange = 0.3
        
        let goal = WeightGoal(
            userId: randomUserId,
            objective: randomObjective,
            startingWeightKg: randomStartingWeight,
            targetWeightKg: randomTargetWeight,
            weeklyChangeKg: randomWeeklyChange
        )
        
        #expect(goal.userId == randomUserId)
        #expect(goal.objective == randomObjective)
        #expect(goal.status == .active)
        #expect(goal.completedAt == nil)
    }
    
    @Test("Test Initialization With Completed Status")
    func testInitializationWithCompletedStatus() {
        let randomUserId = String.random
        let randomCompletedAt = Date.random
        
        let goal = WeightGoal(
            userId: randomUserId,
            objective: .loseWeight,
            startingWeightKg: 75.0,
            targetWeightKg: 68.0,
            weeklyChangeKg: 0.5,
            status: .completed,
            completedAt: randomCompletedAt
        )
        
        #expect(goal.status == .completed)
        #expect(goal.completedAt == randomCompletedAt)
    }
    
    @Test("Test Initialization With Abandoned Status")
    func testInitializationWithAbandonedStatus() {
        let randomUserId = String.random
        
        let goal = WeightGoal(
            userId: randomUserId,
            objective: .maintain,
            startingWeightKg: 70.0,
            targetWeightKg: 70.0,
            weeklyChangeKg: 0.0,
            status: .abandoned
        )
        
        #expect(goal.status == .abandoned)
        #expect(goal.completedAt == nil)
    }
}
