//
//  DietPlan.swift
//  Compound
//
//  Created by Andrew Coyle on 13/10/2025.
//

import Foundation

struct DietPlan: DataSyncModelProtocol, Equatable {
    
    var id: String {
        self.planId
    }
    
    let planId: String
    let userId: String?
    let createdAt: Date
    let tdeeEstimate: Double
    // Selections used
    let preferredDiet: String
    let calorieFloor: String
    let trainingType: String
    let calorieDistribution: String
    let proteinIntake: String
    // 7 entries, one per day
    let days: [DailyMacroTarget]

    static let mock: DietPlan = DietPlan(
        planId: "mock-plan-123",
        userId: "mock-user-456",
        createdAt: Date(),
        tdeeEstimate: 2500,
        preferredDiet: "Balanced",
        calorieFloor: "1800",
        trainingType: "Strength",
        calorieDistribution: "40/30/30",
        proteinIntake: "High",
        days: DailyMacroTarget.mocks
    )
}
