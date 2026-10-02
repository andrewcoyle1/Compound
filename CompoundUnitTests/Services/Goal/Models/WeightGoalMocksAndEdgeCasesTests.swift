//
//  WeightGoalMocksAndEdgeCasesTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 25/10/2025.
//

import Testing
import Foundation
@testable import Compound

@MainActor
struct WeightGoalMocksAndEdgeCasesTests {

    // MARK: - Mock Tests
    
    @Test("Test Mock Property")
    func testMockProperty() {
        let mock = WeightGoal.mock()
        
        #expect(mock.userId == "mockUser")
        #expect(mock.objective == .loseWeight)
        #expect(mock.startingWeightKg == 75.0)
        #expect(mock.targetWeightKg == 68.0)
        #expect(mock.weeklyChangeKg == 0.5)
        #expect(mock.status == .active)
    }
    
    @Test("Test Mock With Custom Parameters")
    func testMockWithCustomParameters() {
        let mock = WeightGoal.mock(
            objective: .gainWeight,
            startingWeightKg: 65.0,
            targetWeightKg: 70.0,
            weeklyChangeKg: 0.3
        )
        
        #expect(mock.objective == .gainWeight)
        #expect(mock.startingWeightKg == 65.0)
        #expect(mock.targetWeightKg == 70.0)
        #expect(mock.weeklyChangeKg == 0.3)
    }
    
    @Test("Test Mocks Property")
    func testMocksProperty() {
        let mocks = WeightGoal.mocks
        
        #expect(mocks.count == 3)
        #expect(mocks[0].objective == .loseWeight)
        #expect(mocks[1].objective == .gainWeight)
        #expect(mocks[2].objective == .maintain)
    }
    
    @Test("Test Mocks Have Different Statuses")
    func testMocksHaveDifferentStatuses() {
        let mocks = WeightGoal.mocks
        
        #expect(mocks[0].status == .active)
        #expect(mocks[1].status == .completed)
        #expect(mocks[2].status == .abandoned)
    }
    
    @Test("Test Mocks Completed Goal Has Completed At Date")
    func testMocksCompletedGoalHasCompletedAtDate() {
        let mocks = WeightGoal.mocks
        
        #expect(mocks[1].status == .completed)
        #expect(mocks[1].completedAt != nil)
    }
    
    @Test("Test Mocks Active Goal Has No Completed At Date")
    func testMocksActiveGoalHasNoCompletedAtDate() {
        let mocks = WeightGoal.mocks
        
        #expect(mocks[0].status == .active)
        #expect(mocks[0].completedAt == nil)
    }
    
    // MARK: - Edge Cases
    
    @Test("Test Goal With Zero Weekly Change")
    func testGoalWithZeroWeeklyChange() {
        let goal = WeightGoal(
            userId: String.random,
            objective: .maintain,
            startingWeightKg: 70.0,
            targetWeightKg: 70.0,
            weeklyChangeKg: 0.0
        )
        
        #expect(goal.isMaintaining == true)
        #expect(goal.totalWeightChange == 0.0)
        #expect(goal.estimatedWeeks == 0)
    }
    
    @Test("Test Goal With Same Start And Target")
    func testGoalWithSameStartAndTarget() {
        let goal = WeightGoal(
            userId: String.random,
            objective: .maintain,
            startingWeightKg: 70.0,
            targetWeightKg: 70.0,
            weeklyChangeKg: 0.5
        )
        
        #expect(goal.totalWeightChange == 0.0)
        #expect(goal.estimatedWeeks == 0)
    }
    
    @Test("Test Progress Calculation Clamped To One")
    func testProgressCalculationClampedToOne() {
        let goal = WeightGoal(
            userId: String.random,
            objective: .loseWeight,
            startingWeightKg: 75.0,
            targetWeightKg: 68.0,
            weeklyChangeKg: 0.5
        )
        
        // If current weight is less than target, progress should be clamped to 1.0
        let progress = goal.calculateProgress(currentWeight: 65.0)
        #expect(progress == 1.0)
    }
    
    @Test("Test Progress Calculation Clamped To Zero")
    func testProgressCalculationClampedToZero() {
        let goal = WeightGoal(
            userId: String.random,
            objective: .loseWeight,
            startingWeightKg: 75.0,
            targetWeightKg: 68.0,
            weeklyChangeKg: 0.5
        )
        
        // If current weight is more than starting weight, progress should be clamped to 0.0
        let progress = goal.calculateProgress(currentWeight: 80.0)
        #expect(progress == 0.0)
    }
    
    @Test("Test Progress Calculation Clamped To Zero For Gaining Goal")
    func testProgressCalculationClampedToZeroForGainingGoal() {
        let goal = WeightGoal(
            userId: String.random,
            objective: .gainWeight,
            startingWeightKg: 65.0,
            targetWeightKg: 70.0,
            weeklyChangeKg: 0.3
        )
        
        // If current weight is less than starting weight, progress should be clamped to 0.0
        let progress = goal.calculateProgress(currentWeight: 60.0)
        #expect(progress == 0.0)
    }
    
    @Test("Test Case Insensitive Objective Matching")
    func testCaseInsensitiveObjectiveMatching() {
        let goal = WeightGoal(
            userId: String.random,
            objective: .loseWeight,
            startingWeightKg: 75.0,
            targetWeightKg: 68.0,
            weeklyChangeKg: 0.5
        )
        
        #expect(goal.isLosing == true)
    }
}
