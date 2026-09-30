//
//  OFFProductDTO.swift
//  DialedIn
//
//  Created by Andrew Coyle on 12/03/2026.
//

import Foundation

extension FoodModel {

    /// An Open Food Facts product's id, from its barcode. Search and barcode lookups used to give
    /// each result a fresh UUID, so logging the same product twice saved it to the library twice.
    static func openFoodFactsId(barcode: String) -> String {
        "off-\(barcode)"
    }
}

struct OFFProductDTO: Decodable {
    let productName: String?
    let brands: String?
    let nutriments: OFFNutrimentsDTO?
    let servingSize: String?
    let servingQuantity: Double?
    let imageFrontSmallUrl: String?
    let imageUrl: String?

    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case brands
        case nutriments
        case servingSize = "serving_size"
        case servingQuantity = "serving_quantity"
        case imageFrontSmallUrl = "image_front_small_url"
        case imageUrl = "image_url"
    }

    func toFoodModel(barcode: String) -> FoodModel? {
        guard let name = productName, !name.isEmpty else { return nil }
        let now = Date()
        let parsed = servingSize.map { parseServingSize($0) }

        return FoodModel(
            ingredientId: FoodModel.openFoodFactsId(barcode: barcode),
            authorId: nil,
            name: name,
            brandName: brands,
            measurementMethod: .weight,
            nutrients: nutrientMap(),
            barcode: barcode,
            servingWeight: servingQuantity,
            portionSize: parsed?.portionSize,
            portionName: parsed?.portionName,
            imageURL: imageFrontSmallUrl ?? imageUrl,
            dateCreated: now,
            dateModified: now
        )
    }

    /// Each nutrient, the OFF names it may be stored under (first found wins), and the factor from
    /// OFF's unit to the app's. OFF normalises every `_100g` value to grams, so a milligram field
    /// is ×1000 and a microgram one ×1,000,000: iron at 0.012 g is 12 mg. They used to be stored
    /// as read, which put every mineral and vitamin a thousand or a million times too low.
    /// Mirrors `OFF_NUTRIENTS` in `functions/lib.js`, which maps search results the same way.
    struct NutrientSource {
        let key: NutrientKey
        let names: [String]
        let factor: Double

        init(_ key: NutrientKey, _ names: [String], _ factor: Double) {
            self.key = key
            self.names = names
            self.factor = factor
        }
    }

    static let nutrientTable: [NutrientSource] = {
        let grams = 1.0, milligrams = 1_000.0, micrograms = 1_000_000.0
        return [
            NutrientSource(.protein, ["proteins"], grams),
            NutrientSource(.carbs, ["carbohydrates"], grams),
            NutrientSource(.fatTotal, ["fat"], grams),
            NutrientSource(.fatSaturated, ["saturated-fat"], grams),
            NutrientSource(.fiber, ["fiber"], grams),
            NutrientSource(.sugar, ["sugars"], grams),
            NutrientSource(.sodiumMg, ["sodium"], milligrams),
            NutrientSource(.potassiumMg, ["potassium"], milligrams),
            NutrientSource(.calciumMg, ["calcium"], milligrams),
            NutrientSource(.ironMg, ["iron"], milligrams),
            NutrientSource(.magnesiumMg, ["magnesium"], milligrams),
            NutrientSource(.zincMg, ["zinc"], milligrams),
            NutrientSource(.phosphorusMg, ["phosphorus"], milligrams),
            NutrientSource(.manganeseMg, ["manganese"], milligrams),
            NutrientSource(.copperMg, ["copper"], milligrams),
            NutrientSource(.chlorideMg, ["chloride"], milligrams),
            NutrientSource(.cholesterolMg, ["cholesterol"], milligrams),
            NutrientSource(.caffeineMg, ["caffeine"], milligrams),
            NutrientSource(.vitaminCMg, ["vitamin-c"], milligrams),
            NutrientSource(.vitaminEMg, ["vitamin-e"], milligrams),
            NutrientSource(.vitaminB6Mg, ["vitamin-b6"], milligrams),
            NutrientSource(.thiaminMg, ["vitamin-b1", "thiamin"], milligrams),
            NutrientSource(.riboflavinMg, ["vitamin-b2", "riboflavin"], milligrams),
            NutrientSource(.niacinMg, ["vitamin-pp", "niacin"], milligrams),
            NutrientSource(.pantothenicAcidMg, ["pantothenic-acid"], milligrams),
            NutrientSource(.vitaminAMcg, ["vitamin-a"], micrograms),
            NutrientSource(.vitaminDMcg, ["vitamin-d"], micrograms),
            NutrientSource(.vitaminKMcg, ["vitamin-k"], micrograms),
            NutrientSource(.vitaminB12Mcg, ["vitamin-b12"], micrograms),
            NutrientSource(.biotinMcg, ["biotin", "vitamin-b7"], micrograms),
            NutrientSource(.folateMcg, ["vitamin-b9", "folates"], micrograms),
            NutrientSource(.iodineMcg, ["iodine"], micrograms),
            NutrientSource(.seleniumMcg, ["selenium"], micrograms)
        ]
    }()

    /// The product's nutrients per 100 g in the app's units. Energy falls back to kilojoules when
    /// a product lists only those.
    func nutrientMap() -> NutrientMap {
        let values = nutriments?.per100g ?? [:]
        var nutrients = NutrientMap()
        if let kcal = values["energy-kcal"] ?? (values["energy-kj"] ?? values["energy"]).map({ $0 / 4.184 }) {
            nutrients[.calories] = kcal
        }
        for entry in Self.nutrientTable {
            if let value = entry.names.lazy.compactMap({ values[$0] }).first {
                nutrients[entry.key] = value * entry.factor
            }
        }
        return nutrients
    }
}
