//
//  NutritionTargetChartInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol NutritionTargetChartInteractor: GlobalInteractor {
    var currentDietPlan: DietPlan? { get }
    func getDailyTotals(dayKey: String) throws -> DailyMacroTarget
}

extension CoreInteractor: NutritionTargetChartInteractor { }
