//
//  DailyNutritionBreakdown.swift
//  Compound
//
//  Created by Andrew Coyle on 06/02/2026.
//

import Foundation

/// Aggregated daily nutrition from meal items + ingredient templates.
/// All values are optional; nil means no data available for that nutrient.
struct DailyNutritionBreakdown {
    // Carb breakdown
    var fiberGrams: Double?
    var sugarGrams: Double?
    /// Net carbs (carbs - fiber) when both available
    var netCarbsGrams: Double?

    // Fat breakdown
    var fatSaturatedGrams: Double?
    var fatMonounsaturatedGrams: Double?
    var fatPolyunsaturatedGrams: Double?

    // Minerals (mg unless noted)
    var sodiumMg: Double?
    var potassiumMg: Double?
    var calciumMg: Double?
    var ironMg: Double?
    var magnesiumMg: Double?
    var zincMg: Double?
    var copperMg: Double?
    var manganeseMg: Double?
    var phosphorusMg: Double?
    var seleniumMcg: Double?

    // Vitamins
    var vitaminAMcg: Double?
    var vitaminB6Mg: Double?
    var vitaminB12Mcg: Double?
    var vitaminCMg: Double?
    var vitaminDMcg: Double?
    var vitaminEMg: Double?
    var vitaminKMcg: Double?
    var thiaminMg: Double?
    var riboflavinMg: Double?
    var niacinMg: Double?
    var pantothenicAcidMg: Double?
    var folateMcg: Double?

    // Other
    var caffeineMg: Double?
    var cholesterolMg: Double?

    static let empty = DailyNutritionBreakdown()
}
