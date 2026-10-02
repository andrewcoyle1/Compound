//
//  DailyMacroTarget.swift
//  Compound
//
//  Created by Andrew Coyle on 13/10/2025.
//

import Foundation

struct DailyMacroTarget: Codable, Equatable {
    let calories: Double
    let proteinGrams: Double
    let carbGrams: Double
    let fatGrams: Double

    static let mock = DailyMacroTarget(
        calories: 2200,
        proteinGrams: 150,
        carbGrams: 250,
        fatGrams: 70
    )
    
    static let mocks = [
        DailyMacroTarget(calories: 2200, proteinGrams: 150, carbGrams: 250, fatGrams: 70),
        DailyMacroTarget(calories: 2100, proteinGrams: 145, carbGrams: 240, fatGrams: 68),
        DailyMacroTarget(calories: 2300, proteinGrams: 155, carbGrams: 260, fatGrams: 72),
        DailyMacroTarget(calories: 2250, proteinGrams: 152, carbGrams: 255, fatGrams: 71),
        DailyMacroTarget(calories: 2150, proteinGrams: 148, carbGrams: 245, fatGrams: 69),
        DailyMacroTarget(calories: 2350, proteinGrams: 158, carbGrams: 265, fatGrams: 73),
        DailyMacroTarget(calories: 2200, proteinGrams: 150, carbGrams: 250, fatGrams: 70)
    ]
}
