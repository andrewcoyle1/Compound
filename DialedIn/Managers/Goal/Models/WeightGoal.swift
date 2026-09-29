//
//  WeightGoal.swift
//  DialedIn
//
//  Created by Andrew Coyle on 20/10/2025.
//

import Foundation

struct WeightGoal: DataSyncModelProtocol, Equatable {
    
    var id: String { userId }
    
    let userId: String
    let objective: OverarchingObjective
    let startingWeightKg: Double
    let targetWeightKg: Double
    let weeklyChangeKg: Double
    let createdAt: Date
    let status: GoalStatus
    let completedAt: Date?
        
    init(
        userId: String,
        objective: OverarchingObjective,
        startingWeightKg: Double,
        targetWeightKg: Double,
        weeklyChangeKg: Double,
        createdAt: Date = Date(),
        status: GoalStatus = .active,
        completedAt: Date? = nil
    ) {
        self.userId = userId
        self.objective = objective
        self.startingWeightKg = startingWeightKg
        self.targetWeightKg = targetWeightKg
        self.weeklyChangeKg = weeklyChangeKg
        self.createdAt = createdAt
        self.status = status
        self.completedAt = completedAt
    }
    
    enum GoalStatus: String, Codable {
        case active
        case completed
        case abandoned
        case paused
        
        var displayName: String {
            switch self {
            case .active: return String(localized: "Active")
            case .completed: return String(localized: "Completed")
            case .abandoned: return String(localized: "Abandoned")
            case .paused: return String(localized: "Paused")
            }
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case objective
        case startingWeightKg = "starting_weight_kg"
        case targetWeightKg = "target_weight_kg"
        case weeklyChangeKg = "weekly_change_kg"
        case createdAt = "created_at"
        case status
        case completedAt = "completed_at"
    }
    
    // MARK: - Computed Properties
    
    var isLosing: Bool {
        objective.description.lowercased().contains("lose")
    }
    
    var isGaining: Bool {
        objective.description.lowercased().contains("gain")
    }
    
    var isMaintaining: Bool {
        objective.description.lowercased().contains("maintain")
    }
    
    var totalWeightChange: Double {
        abs(targetWeightKg - startingWeightKg)
    }
    
    var estimatedWeeks: Int {
        guard weeklyChangeKg > 0 else { return 0 }
        return Int(ceil(totalWeightChange / weeklyChangeKg))
    }
    
    var estimatedMonths: Int {
        Int(ceil(Double(estimatedWeeks) / 4.33))
    }
    
    func calculateProgress(currentWeight: Double) -> Double {
        guard targetWeightKg != startingWeightKg else { return 0 }
        
        // Determine if this is a losing or gaining goal
        let isLosingGoal = targetWeightKg < startingWeightKg
        
        // Check if current weight is moving in the right direction
        let movingRightDirection: Bool
        if isLosingGoal {
            // For losing weight: current must be less than starting
            movingRightDirection = currentWeight < startingWeightKg
        } else {
            // For gaining weight: current must be greater than starting
            movingRightDirection = currentWeight > startingWeightKg
        }
        
        // If moving in wrong direction, return 0 progress
        if !movingRightDirection {
            return 0
        }
        
        // Calculate progress based on how far we've moved towards the target
        let totalChange = abs(targetWeightKg - startingWeightKg)
        let currentChange = abs(startingWeightKg - currentWeight)
        let progress = min(max(currentChange / totalChange, 0), 1)
        return progress
    }
    
    func weightChanged(currentWeight: Double) -> Double {
        startingWeightKg - currentWeight
    }
    
    func weightRemaining(currentWeight: Double) -> Double {
        abs(targetWeightKg - currentWeight)
    }
}

// MARK: - Mock Data
extension WeightGoal {
    static func mock(
        objective: OverarchingObjective = .loseWeight,
        startingWeightKg: Double = 75.0,
        targetWeightKg: Double = 68.0,
        weeklyChangeKg: Double = 0.5
    ) -> WeightGoal {
        WeightGoal(
            userId: "mockUser",
            objective: objective,
            startingWeightKg: startingWeightKg,
            targetWeightKg: targetWeightKg,
            weeklyChangeKg: weeklyChangeKg,
            createdAt: Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date(),
            status: .active
        )
    }
    
    static let mocks: [WeightGoal] = [
        mock(objective: .loseWeight, startingWeightKg: 75.0, targetWeightKg: 68.0),
        WeightGoal(
            userId: "mockUser",
            objective: .gainWeight,
            startingWeightKg: 65.0,
            targetWeightKg: 70.0,
            weeklyChangeKg: 0.3,
            createdAt: Calendar.current.date(byAdding: .month, value: -2, to: Date()) ?? Date(),
            status: .completed,
            completedAt: Calendar.current.date(byAdding: .day, value: -5, to: Date())
        ),
        WeightGoal(
            userId: "mockUser",
            objective: .maintain,
            startingWeightKg: 70.0,
            targetWeightKg: 70.0,
            weeklyChangeKg: 0.0,
            createdAt: Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date(),
            status: .abandoned
        )
    ]
}
