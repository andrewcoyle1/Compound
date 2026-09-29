//
//  Macro.swift
//  DialedIn
//
//  Created by Andrew Coyle on 12/03/2026.
//

import SwiftUI

enum Macro: CaseIterable {
    case cals
    case fat
    case protein
    case carbs

    var title: String {
        switch self {
        case .cals: return String(localized: "Cals")
        case .carbs: return String(localized: "Carbs")
        case .fat: return String(localized: "Fat")
        case .protein: return String(localized: "Protein")
        }
    }

    var iconName: String {
        switch self {
        case .cals: return "flame"
        case .carbs: return "carrot"
        case .fat: return "drop"
        case .protein: return "bolt"
        }
    }

    var colour: Color {
        switch self {
        case .cals: return .blue
        case .carbs: return .carbsColor
        case .fat: return .fatColor
        case .protein: return .proteinColor
        }
    }

    var nutrientKey: NutrientKey {
        switch self {
        case .cals: return .calories
        case .fat: return .fatTotal
        case .protein: return .protein
        case .carbs: return .carbs
        }
    }

    static var proteinColor: Color { Color(red: 0.9, green: 0.4, blue: 0.3) }
    static var fatColor: Color { Color(red: 0.95, green: 0.75, blue: 0.2) }
    static var carbsColor: Color { Color(red: 0.4, green: 0.75, blue: 0.5) }
}

protocol MacroNutrient {
    var name: String { get }
    var unit: String { get }
}

enum Macros: String, CaseIterable {
    case protein
    case fat
    case carbs
    case vitamins
    case minerals
    case other

    var name: String {
        switch self {
        case .carbs: return String(localized: "Carbohydrates")
        case .fat: return String(localized: "Fat")
        case .protein: return String(localized: "Protein")
        case .vitamins: return String(localized: "Vitamins")
        case .minerals: return String(localized: "Minerals")
        case .other: return String(localized: "Other")
        }
    }

    var details: [NutrientKey] {
        NutrientKey.allCases.filter { $0.category == self }
    }
}

enum NutrientKey: String, CaseIterable, Codable, Hashable, MacroNutrient {
    // Core macros
    case calories
    case protein
    case carbs
    case fatTotal             = "fat_total"
    // Fat breakdown
    case fatSaturated         = "fat_saturated"
    case fatMonounsaturated   = "fat_monounsaturated"
    case fatPolyunsaturated   = "fat_polyunsaturated"
    case fatTrans             = "fat_trans"
    case omega3               = "omega_3"
    case omega3Ala            = "omega_3_ala"
    case omega3Dha            = "omega_3_dha"
    case omega3Epa            = "omega_3_epa"
    case omega6               = "omega_6"
    // Carb breakdown
    case fiber
    case sugar
    case addedSugars          = "added_sugars"
    case starch
    // Amino acids
    case cysteine
    case histidine
    case isoleucine
    case leucine
    case lysine
    case methionine
    case phenylalanine
    case threonine
    case tryptophan
    case tyrosine
    case valine
    // Minerals
    case sodiumMg             = "sodium_mg"
    case potassiumMg          = "potassium_mg"
    case calciumMg            = "calcium_mg"
    case ironMg               = "iron_mg"
    case magnesiumMg          = "magnesium_mg"
    case zincMg               = "zinc_mg"
    case copperMg             = "copper_mg"
    case manganeseMg          = "manganese_mg"
    case phosphorusMg         = "phosphorus_mg"
    case seleniumMcg          = "selenium_mcg"
    case chlorideMg           = "chloride_mg"
    case chromiumMcg          = "chromium_mcg"
    case molybdenumMcg        = "molybdenum_mcg"
    // Vitamins
    case vitaminAMcg          = "vitamin_a_mcg"
    case vitaminB6Mg          = "vitamin_b6_mg"
    case vitaminB12Mcg        = "vitamin_b12_mcg"
    case vitaminCMg           = "vitamin_c_mg"
    case vitaminDMcg          = "vitamin_d_mcg"
    case vitaminEMg           = "vitamin_e_mg"
    case vitaminKMcg          = "vitamin_k_mcg"
    case biotinMcg            = "biotin_mcg"
    case folateMcg            = "folate_mcg"
    case iodineMcg            = "iodine_mcg"
    case niacinMg             = "niacin_mg"
    case thiaminMg            = "thiamin_mg"
    case riboflavinMg         = "riboflavin_mg"
    case pantothenicAcidMg    = "pantothenic_acid_mg"
    // Other
    case caffeineMg           = "caffeine_mg"
    case cholesterolMg        = "cholesterol_mg"
    case alcohol
    case water

    var name: String {
        switch self {
        case .calories:           return String(localized: "Calories")
        case .protein:            return String(localized: "Protein")
        case .carbs:              return String(localized: "Carbohydrates")
        case .fatTotal:           return String(localized: "Total Fat")
        case .fatSaturated:       return String(localized: "Saturated Fat")
        case .fatMonounsaturated: return String(localized: "Monounsaturated Fat")
        case .fatPolyunsaturated: return String(localized: "Polyunsaturated Fat")
        case .fatTrans:           return String(localized: "Trans Fat")
        case .omega3:             return String(localized: "Omega-3")
        case .omega3Ala:          return String(localized: "Omega-3 ALA")
        case .omega3Dha:          return String(localized: "Omega-3 DHA")
        case .omega3Epa:          return String(localized: "Omega-3 EPA")
        case .omega6:             return String(localized: "Omega-6")
        case .fiber:              return String(localized: "Fiber")
        case .sugar:              return String(localized: "Sugar")
        case .addedSugars:        return String(localized: "Added Sugars")
        case .starch:             return String(localized: "Starch")
        case .cysteine:           return String(localized: "Cysteine")
        case .histidine:          return String(localized: "Histidine")
        case .isoleucine:         return String(localized: "Isoleucine")
        case .leucine:            return String(localized: "Leucine")
        case .lysine:             return String(localized: "Lysine")
        case .methionine:         return String(localized: "Methionine")
        case .phenylalanine:      return String(localized: "Phenylalanine")
        case .threonine:          return String(localized: "Threonine")
        case .tryptophan:         return String(localized: "Tryptophan")
        case .tyrosine:           return String(localized: "Tyrosine")
        case .valine:             return String(localized: "Valine")
        case .sodiumMg:           return String(localized: "Sodium")
        case .potassiumMg:        return String(localized: "Potassium")
        case .calciumMg:          return String(localized: "Calcium")
        case .ironMg:             return String(localized: "Iron")
        case .magnesiumMg:        return String(localized: "Magnesium")
        case .zincMg:             return String(localized: "Zinc")
        case .copperMg:           return String(localized: "Copper")
        case .manganeseMg:        return String(localized: "Manganese")
        case .phosphorusMg:       return String(localized: "Phosphorus")
        case .seleniumMcg:        return String(localized: "Selenium")
        case .chlorideMg:         return String(localized: "Chloride")
        case .chromiumMcg:        return String(localized: "Chromium")
        case .molybdenumMcg:      return String(localized: "Molybdenum")
        case .vitaminAMcg:        return String(localized: "Vitamin A")
        case .vitaminB6Mg:        return String(localized: "Vitamin B6")
        case .vitaminB12Mcg:      return String(localized: "Vitamin B12")
        case .vitaminCMg:         return String(localized: "Vitamin C")
        case .vitaminDMcg:        return String(localized: "Vitamin D")
        case .vitaminEMg:         return String(localized: "Vitamin E")
        case .vitaminKMcg:        return String(localized: "Vitamin K")
        case .biotinMcg:          return String(localized: "Biotin")
        case .folateMcg:          return String(localized: "Folate")
        case .iodineMcg:          return String(localized: "Iodine")
        case .niacinMg:           return String(localized: "Niacin")
        case .thiaminMg:          return String(localized: "Thiamin")
        case .riboflavinMg:       return String(localized: "Riboflavin")
        case .pantothenicAcidMg:  return String(localized: "Pantothenic Acid")
        case .caffeineMg:         return String(localized: "Caffeine")
        case .cholesterolMg:      return String(localized: "Cholesterol")
        case .alcohol:            return String(localized: "Alcohol")
        case .water:              return String(localized: "Water")
        }
    }

    var unit: String {
        switch self {
        case .calories:
            return "kcal"
        case .protein, .carbs, .fatTotal, .fatSaturated, .fatMonounsaturated,
             .fatPolyunsaturated, .fatTrans, .omega3, .omega3Ala, .omega3Dha, .omega3Epa, .omega6,
             .fiber, .sugar, .addedSugars, .starch,
             .cysteine, .histidine, .isoleucine, .leucine, .lysine, .methionine, .phenylalanine,
             .threonine, .tryptophan, .tyrosine, .valine,
             .alcohol, .water:
            return "g"
        case .sodiumMg, .potassiumMg, .calciumMg, .ironMg, .magnesiumMg, .zincMg, .copperMg,
             .manganeseMg, .phosphorusMg, .chlorideMg, .vitaminB6Mg, .vitaminCMg, .vitaminEMg,
             .niacinMg, .thiaminMg, .riboflavinMg, .pantothenicAcidMg, .caffeineMg, .cholesterolMg:
            return "mg"
        case .seleniumMcg, .chromiumMcg, .molybdenumMcg, .vitaminAMcg, .vitaminB12Mcg,
             .vitaminDMcg, .vitaminKMcg, .biotinMcg, .folateMcg, .iodineMcg:
            return "mcg"
        }
    }

    var category: Macros? {
        switch self {
        case .calories:
            return nil
        case .protein, .cysteine, .histidine, .isoleucine, .leucine, .lysine, .methionine,
             .phenylalanine, .threonine, .tryptophan, .tyrosine, .valine:
            return .protein
        case .carbs, .fiber, .sugar, .addedSugars, .starch:
            return .carbs
        case .fatTotal, .fatSaturated, .fatMonounsaturated, .fatPolyunsaturated, .fatTrans,
             .omega3, .omega3Ala, .omega3Dha, .omega3Epa, .omega6:
            return .fat
        case .sodiumMg, .potassiumMg, .calciumMg, .ironMg, .magnesiumMg, .zincMg, .copperMg,
             .manganeseMg, .phosphorusMg, .seleniumMcg, .chlorideMg, .chromiumMcg, .molybdenumMcg:
            return .minerals
        case .vitaminAMcg, .vitaminB6Mg, .vitaminB12Mcg, .vitaminCMg, .vitaminDMcg, .vitaminEMg,
             .vitaminKMcg, .biotinMcg, .folateMcg, .iodineMcg, .niacinMg, .thiaminMg, .riboflavinMg,
             .pantothenicAcidMg:
            return .vitamins
        case .caffeineMg, .cholesterolMg, .alcohol, .water:
            return .other
        }
    }
}
