//
//  WeightGoalEqualityAndCodableTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 25/10/2025.
//

import Testing
import Foundation
@testable import Compound

@MainActor
struct WeightGoalEqualityAndCodableTests {

    // MARK: - Equatable Tests
    
    @Test("Test Equality With Same Properties")
    func testEqualityWithSameProperties() {
        let randomUserId = String.random
        let randomObjective = OverarchingObjective.loseWeight
        let randomCreatedAt = Date.random
        
        let goal1 = WeightGoal(
            userId: randomUserId,
            objective: randomObjective,
            startingWeightKg: 75.0,
            targetWeightKg: 68.0,
            weeklyChangeKg: 0.5,
            createdAt: randomCreatedAt,
            status: .active
        )
        
        let goal2 = WeightGoal(
            userId: randomUserId,
            objective: randomObjective,
            startingWeightKg: 75.0,
            targetWeightKg: 68.0,
            weeklyChangeKg: 0.5,
            createdAt: randomCreatedAt,
            status: .active
        )
        
        #expect(goal1 == goal2)
    }
    
    /// A goal used to carry its own `goalId`; a user now has one weight goal, identified by their
    /// own id, so that is what the sync engine writes it under.
    @Test("Test Goal Is Identified By Its User")
    func testGoalIsIdentifiedByItsUser() {
        let randomUserId = String.random
        
        let goal = WeightGoal(
            userId: randomUserId,
            objective: .loseWeight,
            startingWeightKg: 75.0,
            targetWeightKg: 68.0,
            weeklyChangeKg: 0.5
        )
        
        #expect(goal.id == randomUserId)
    }
    
    @Test("Test Inequality With Different User")
    func testInequalityWithDifferentUser() {
        let goal1 = WeightGoal(
            userId: String.random,
            objective: .loseWeight,
            startingWeightKg: 75.0,
            targetWeightKg: 68.0,
            weeklyChangeKg: 0.5
        )
        
        let goal2 = WeightGoal(
            userId: String.random,
            objective: .loseWeight,
            startingWeightKg: 75.0,
            targetWeightKg: 68.0,
            weeklyChangeKg: 0.5
        )
        
        #expect(goal1 != goal2)
    }
    
    @Test("Test Inequality With Different Objective")
    func testInequalityWithDifferentObjective() {
        let randomUserId = String.random
        
        let goal1 = WeightGoal(
            userId: randomUserId,
            objective: .loseWeight,
            startingWeightKg: 75.0,
            targetWeightKg: 68.0,
            weeklyChangeKg: 0.5
        )
        
        let goal2 = WeightGoal(
            userId: randomUserId,
            objective: .gainWeight,
            startingWeightKg: 75.0,
            targetWeightKg: 80.0,
            weeklyChangeKg: 0.5
        )
        
        #expect(goal1 != goal2)
    }
    
    @Test("Test Inequality With Different Status")
    func testInequalityWithDifferentStatus() {
        let randomUserId = String.random
        let randomCreatedAt = Date.random
        
        let goal1 = WeightGoal(
            userId: randomUserId,
            objective: .loseWeight,
            startingWeightKg: 75.0,
            targetWeightKg: 68.0,
            weeklyChangeKg: 0.5,
            createdAt: randomCreatedAt,
            status: .active
        )
        
        let goal2 = WeightGoal(
            userId: randomUserId,
            objective: .loseWeight,
            startingWeightKg: 75.0,
            targetWeightKg: 68.0,
            weeklyChangeKg: 0.5,
            createdAt: randomCreatedAt,
            status: .completed
        )
        
        #expect(goal1 != goal2)
    }
    
    // MARK: - Codable Tests
    
    @Test("Test Encoding And Decoding")
    func testEncodingAndDecoding() throws {
        let randomUserId = String.random
        let randomCreatedAt = Date.random
        let randomCompletedAt = Date.random
        
        let originalGoal = WeightGoal(
            userId: randomUserId,
            objective: .loseWeight,
            startingWeightKg: 75.0,
            targetWeightKg: 68.0,
            weeklyChangeKg: 0.5,
            createdAt: randomCreatedAt,
            status: .completed,
            completedAt: randomCompletedAt
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let encodedData = try encoder.encode(originalGoal)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let decodedGoal = try decoder.decode(WeightGoal.self, from: encodedData)
        
        // With millisecondsSince1970, dates preserve sub-second precision
        #expect(decodedGoal.userId == originalGoal.userId)
        #expect(decodedGoal.objective == originalGoal.objective)
        #expect(decodedGoal.startingWeightKg == originalGoal.startingWeightKg)
        #expect(decodedGoal.targetWeightKg == originalGoal.targetWeightKg)
        #expect(decodedGoal.weeklyChangeKg == originalGoal.weeklyChangeKg)
        #expect(abs(decodedGoal.createdAt.timeIntervalSince1970 - originalGoal.createdAt.timeIntervalSince1970) < 0.001)
        #expect(decodedGoal.status == originalGoal.status)
        if let decodedCompletedAt = decodedGoal.completedAt, let originalCompletedAt = originalGoal.completedAt {
            #expect(abs(decodedCompletedAt.timeIntervalSince1970 - originalCompletedAt.timeIntervalSince1970) < 0.001)
        } else {
            #expect(decodedGoal.completedAt == originalGoal.completedAt)
        }
    }
    
    @Test("Test Encoding Nil Completed At")
    func testEncodingNilCompletedAt() throws {
        let randomUserId = String.random
        let randomCreatedAt = Date.random
        
        let goal = WeightGoal(
            userId: randomUserId,
            objective: .loseWeight,
            startingWeightKg: 75.0,
            targetWeightKg: 68.0,
            weeklyChangeKg: 0.5,
            createdAt: randomCreatedAt,
            status: .active,
            completedAt: nil
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let encodedData = try encoder.encode(goal)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let decodedGoal = try decoder.decode(WeightGoal.self, from: encodedData)
        
        #expect(decodedGoal.userId == randomUserId)
        #expect(decodedGoal.completedAt == nil)
    }
    
    @Test("Test Coding Keys Mapping")
    func testCodingKeysMapping() throws {
        let randomUserId = String.random
        
        let goal = WeightGoal(
            userId: randomUserId,
            objective: .loseWeight,
            startingWeightKg: 75.0,
            targetWeightKg: 68.0,
            weeklyChangeKg: 0.5,
            status: .active
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let encodedData = try encoder.encode(goal)
        
        let json = try JSONSerialization.jsonObject(with: encodedData) as? [String: Any]
        
        #expect(json?["user_id"] as? String == randomUserId)
        // `OverarchingObjective` has no string raw value, so it encodes as a keyed case rather than
        // a plain string; the round-trip above is what pins its stored shape.
        #expect(json?["objective"] != nil)
        #expect(json?["starting_weight_kg"] as? Double == 75.0)
        #expect(json?["target_weight_kg"] as? Double == 68.0)
        #expect(json?["weekly_change_kg"] as? Double == 0.5)
        #expect(json?["status"] as? String == "active")
    }
    
    // MARK: - GoalStatus Enum Tests
    
    @Test("Test GoalStatus Raw Values")
    func testGoalStatusRawValues() {
        #expect(WeightGoal.GoalStatus.active.rawValue == "active")
        #expect(WeightGoal.GoalStatus.completed.rawValue == "completed")
        #expect(WeightGoal.GoalStatus.abandoned.rawValue == "abandoned")
        #expect(WeightGoal.GoalStatus.paused.rawValue == "paused")
    }
    
    @Test("Test GoalStatus Display Names")
    func testGoalStatusDisplayNames() {
        #expect(WeightGoal.GoalStatus.active.displayName == "Active")
        #expect(WeightGoal.GoalStatus.completed.displayName == "Completed")
        #expect(WeightGoal.GoalStatus.abandoned.displayName == "Abandoned")
        #expect(WeightGoal.GoalStatus.paused.displayName == "Paused")
    }
}
