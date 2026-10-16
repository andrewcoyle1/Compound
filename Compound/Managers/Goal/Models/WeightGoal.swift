//
//  WeightGoal.swift
//  Compound
//
//  Created by Andrew Coyle on 20/10/2025.
//

import Foundation

struct WeightGoal: DataSyncModelProtocol, Equatable, ReplacesClearedFields {
    
    /// The goal's own document. Goals are frozen once written (`firestore.rules` refuses changes to
    /// their figures), so a new goal is a new document and the user's `currentGoalId` points at it.
    /// Goals saved before this had one fixed document named after the user, and decode with that id.
    let id: String
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
        completedAt: Date? = nil,
        id: String? = nil
    ) {
        self.id = id ?? userId
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
    
    enum CodingKeys: String, CodingKey, CaseIterable {
        case id = "goal_id"
        case userId = "user_id"
        case objective
        case startingWeightKg = "starting_weight_kg"
        case targetWeightKg = "target_weight_kg"
        case weeklyChangeKg = "weekly_change_kg"
        case createdAt = "created_at"
        case status
        case completedAt = "completed_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(String.self, forKey: .userId)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? userId
        startingWeightKg = try container.decode(Double.self, forKey: .startingWeightKg)
        targetWeightKg = try container.decode(Double.self, forKey: .targetWeightKg)
        weeklyChangeKg = try container.decode(Double.self, forKey: .weeklyChangeKg)
        objective = try Self.objective(in: container, weeklyChangeKg: weeklyChangeKg)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        status = try container.decode(GoalStatus.self, forKey: .status)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
    }

    /// The stored objective, repairing one that holds two cases where the figures say which.
    ///
    /// Builds that merge-saved an edited goal left the old objective's key beside the new one,
    /// `{"loseWeight": {}, "maintain": {}}`, which the synthesized decoder refuses, so the goal
    /// vanished. Maintaining is the only objective saved with a weekly rate of 0 (losing and
    /// gaining start at 0.25% and 0.1% of body weight), so when exactly one stored case fits the
    /// rate, it is the one the edit wrote. Losing beside gaining stays unreadable: nothing stored
    /// says which came last, and the direction from start to target does not either, because an
    /// edit keeps the start. The next save writes the map whole and drops the other key.
    private static func objective(in container: KeyedDecodingContainer<CodingKeys>, weeklyChangeKg: Double) throws -> OverarchingObjective {
        do {
            return try container.decode(OverarchingObjective.self, forKey: .objective)
        } catch {
            // The case names the synthesized coding stores as keys.
            let cases: [String: OverarchingObjective] = ["loseWeight": .loseWeight, "maintain": .maintain, "gainWeight": .gainWeight]
            let stored = try container.nestedContainer(keyedBy: AnyCodingKey.self, forKey: .objective).allKeys.compactMap { cases[$0.stringValue] }
            let fitting = stored.filter { ($0 == .maintain) == (weeklyChangeKg == 0) }
            guard fitting.count == 1, let objective = fitting.first else { throw error }
            return objective
        }
    }

    // MARK: - Computed Properties
    
    // On the enum, not its localized description, which reads "Perder peso" in Spanish.
    var isLosing: Bool {
        objective == .loseWeight
    }
    
    var isGaining: Bool {
        objective == .gainWeight
    }
    
    var isMaintaining: Bool {
        objective == .maintain
    }
    
    var totalWeightChange: Double {
        abs(targetWeightKg - startingWeightKg)
    }
    
    /// Distance ÷ rate, rounded up (`GoalTimeline.weeks`). The rate is held by re-targeting, so
    /// the calorie target steps down along the way rather than staying fixed.
    var estimatedWeeks: Int {
        guard weeklyChangeKg > 0 else { return 0 }
        return GoalTimeline.weeks(distanceKg: totalWeightChange, weeklyRateKg: weeklyChangeKg)
    }
    
    var estimatedMonths: Int {
        Int(ceil(Double(estimatedWeeks) / 4.33))
    }
    
    /// The share of the way from the starting weight to the target, 0...1. Pass the trend weight
    /// (`GoalTimeline.latestTrendWeightKg`), not the last weigh-in, so a day of water or salt does
    /// not move it.
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
