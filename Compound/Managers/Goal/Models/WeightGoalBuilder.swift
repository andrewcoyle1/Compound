//
//  WeightGoalBuilder.swift
//  Compound
//
//  Created by Andrew Coyle on 10/31/25.
//

import Foundation

struct WeightGoalBuilder: Sendable, Hashable {
    var objective: OverarchingObjective
    var targetWeightKg: Double?
    var weeklyChangeKg: Double?

    var eventParameters: [String: Any] {
        let params = [
            "gender": self.objective.description as Any,
            "dateOfBirth": self.targetWeightKg as Any,
            "height": self.weeklyChangeKg as Any
        ]

        return params
    }

    mutating func setTargetWeight(_ targetWeight: Double) {
        self.targetWeightKg = targetWeight
    }

    mutating func setWeeklyChange(_ weeklyChange: Double) {
        self.weeklyChangeKg = weeklyChange
    }

    static var targetWeightMock: WeightGoalBuilder {
        WeightGoalBuilder(
            objective: .loseWeight
        )
    }

    static var weightRateMock: WeightGoalBuilder {
        WeightGoalBuilder(
            objective: .loseWeight,
            targetWeightKg: 75
        )
    }

    static var mock: WeightGoalBuilder {
        WeightGoalBuilder(
            objective: .loseWeight,
            targetWeightKg: 75,
            weeklyChangeKg: 0.5
        )
    }
}
