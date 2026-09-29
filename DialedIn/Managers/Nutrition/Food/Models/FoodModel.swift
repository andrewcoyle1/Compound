//
//  FoodModel.swift
//  DialedIn
//
//  Created by Andrew Coyle on 23/09/2025.
//

import Foundation

struct FoodModel: DataSyncModelProtocol, SearchListItem, FoodItem {

    var id: String { ingredientId }

    let ingredientId: String
    let authorId: String?
    let name: String
    let brandName: String?
    let description: String?
    let measurementMethod: MeasurementMethod

    // MARK: Nutrients (dictionary-backed)
    let nutrients: NutrientMap

    // MARK: Convenience subscript
    subscript(key: NutrientKey) -> Double? { nutrients[key] }

    // MARK: Computed wrappers — keep existing read-sites working
    var calories: Double? { nutrients[.calories] }
    var protein: Double? { nutrients[.protein] }
    var carbs: Double? { nutrients[.carbs] }
    var fatTotal: Double? { nutrients[.fatTotal] }
    var fats: Double? { nutrients[.fatTotal] }
    var fatSaturated: Double? { nutrients[.fatSaturated] }
    var fatMonounsaturated: Double? { nutrients[.fatMonounsaturated] }
    var fatPolyunsaturated: Double? { nutrients[.fatPolyunsaturated] }
    var fiber: Double? { nutrients[.fiber] }
    var sugar: Double? { nutrients[.sugar] }
    var sodiumMg: Double? { nutrients[.sodiumMg] }
    var potassiumMg: Double? { nutrients[.potassiumMg] }
    var calciumMg: Double? { nutrients[.calciumMg] }
    var ironMg: Double? { nutrients[.ironMg] }
    var vitaminAMcg: Double? { nutrients[.vitaminAMcg] }
    var vitaminB6Mg: Double? { nutrients[.vitaminB6Mg] }
    var vitaminB12Mcg: Double? { nutrients[.vitaminB12Mcg] }
    var vitaminCMg: Double? { nutrients[.vitaminCMg] }
    var vitaminDMcg: Double? { nutrients[.vitaminDMcg] }
    var vitaminEMg: Double? { nutrients[.vitaminEMg] }
    var vitaminKMcg: Double? { nutrients[.vitaminKMcg] }
    var magnesiumMg: Double? { nutrients[.magnesiumMg] }
    var zincMg: Double? { nutrients[.zincMg] }
    var biotinMcg: Double? { nutrients[.biotinMcg] }
    var copperMg: Double? { nutrients[.copperMg] }
    var folateMcg: Double? { nutrients[.folateMcg] }
    var iodineMcg: Double? { nutrients[.iodineMcg] }
    var niacinMg: Double? { nutrients[.niacinMg] }
    var thiaminMg: Double? { nutrients[.thiaminMg] }
    var caffeineMg: Double? { nutrients[.caffeineMg] }
    var chlorideMg: Double? { nutrients[.chlorideMg] }
    var chromiumMcg: Double? { nutrients[.chromiumMcg] }
    var seleniumMcg: Double? { nutrients[.seleniumMcg] }
    var manganeseMg: Double? { nutrients[.manganeseMg] }
    var molybdenumMcg: Double? { nutrients[.molybdenumMcg] }
    var phosphorusMg: Double? { nutrients[.phosphorusMg] }
    var riboflavinMg: Double? { nutrients[.riboflavinMg] }
    var cholesterolMg: Double? { nutrients[.cholesterolMg] }
    var pantothenicAcidMg: Double? { nutrients[.pantothenicAcidMg] }

    let barcode: String?

    // MARK: Portion definition
    let servingWeight: Double?
    let portionSize: Double?
    let portionName: String?

    let portionWeight: Double?
    let weightPortionSize: Double?
    let weightPortionName: String?

    let portionVolume: Double?
    let volumePortionSize: Double?
    let volumePortionName: String?

    private(set) var imageURL: String?
    let dateCreated: Date
    let dateModified: Date
    let clickCount: Int?
    let bookmarkCount: Int?
    let favouriteCount: Int?

    init(
        ingredientId: String = UUID().uuidString,
        authorId: String? = nil,
        name: String,
        brandName: String? = nil,
        description: String? = nil,
        measurementMethod: MeasurementMethod = .weight,
        nutrients: NutrientMap = NutrientMap(),
        barcode: String? = nil,
        servingWeight: Double? = nil,
        portionSize: Double? = nil,
        portionName: String? = nil,
        portionWeight: Double? = nil,
        weightPortionSize: Double? = nil,
        weightPortionName: String? = nil,
        portionVolume: Double? = nil,
        volumePortionSize: Double? = nil,
        volumePortionName: String? = nil,
        imageURL: String? = nil,
        dateCreated: Date = Date(),
        dateModified: Date = Date(),
        clickCount: Int? = nil,
        bookmarkCount: Int? = nil,
        favouriteCount: Int? = nil
    ) {
        self.ingredientId = ingredientId
        self.authorId = authorId
        self.name = name
        self.brandName = brandName
        self.description = description
        self.measurementMethod = measurementMethod
        self.nutrients = nutrients
        self.barcode = barcode
        self.servingWeight = servingWeight
        self.portionSize = portionSize
        self.portionName = portionName
        self.portionWeight = portionWeight
        self.weightPortionSize = weightPortionSize
        self.weightPortionName = weightPortionName
        self.portionVolume = portionVolume
        self.volumePortionSize = volumePortionSize
        self.volumePortionName = volumePortionName
        self.imageURL = imageURL
        self.dateCreated = dateCreated
        self.dateModified = dateModified
        self.clickCount = clickCount
        self.bookmarkCount = bookmarkCount
        self.favouriteCount = favouriteCount
    }

    mutating func updateImageURL(imageUrl: String) {
        self.imageURL = imageUrl
    }

    // MARK: Computed portion helpers

    /// Grams in one canonical serving/portion. Prefers serving weight, falls back to mass portion weight.
    var portionGramsCalculated: Double? {
        servingWeight ?? portionWeight
    }

    /// Millilitres in one canonical portion (volume-based foods only).
    var portionMillilitersCalculated: Double? {
        portionVolume
    }

    /// Display quantity for one portion, e.g. 4 for "4 pieces".
    var portionQuantityCalculated: Double? {
        portionSize ?? weightPortionSize ?? volumePortionSize
    }

    /// Display name for the portion unit, e.g. "pieces".
    var portionNameCalculated: String? {
        // Safe: `$0 != nil &&` short-circuits before the unwrap.
        [portionName, weightPortionName, volumePortionName].first(where: { $0 != nil && !$0!.isEmpty }) ?? nil
    }

    func withAuthorId(_ id: String) -> FoodModel {
        FoodModel(
            ingredientId: ingredientId, authorId: id, name: name, brandName: brandName,
            description: description, measurementMethod: measurementMethod,
            nutrients: nutrients, barcode: barcode,
            servingWeight: servingWeight, portionSize: portionSize, portionName: portionName,
            portionWeight: portionWeight, weightPortionSize: weightPortionSize,
            weightPortionName: weightPortionName,
            portionVolume: portionVolume, volumePortionSize: volumePortionSize,
            volumePortionName: volumePortionName, imageURL: imageURL,
            dateCreated: dateCreated, dateModified: dateModified,
            clickCount: clickCount, bookmarkCount: bookmarkCount, favouriteCount: favouriteCount
        )
    }

    enum CodingKeys: String, CodingKey {
        case ingredientId    = "ingredient_id"
        case authorId        = "author_id"
        case name
        case brandName       = "brand_name"
        case description
        case measurementMethod = "measurement_method"
        case nutrients
        case barcode
        case servingWeight   = "serving_weight"
        case portionSize     = "portion_size"
        case portionName     = "portion_name"
        case portionWeight   = "portion_weight"
        case weightPortionSize  = "weight_portion_size"
        case weightPortionName  = "weight_portion_name"
        case portionVolume   = "portion_volume"
        case volumePortionSize  = "volume_portion_size"
        case volumePortionName  = "volume_portion_name"
        case imageURL        = "image_url"
        case dateCreated     = "date_created"
        case dateModified    = "date_modified"
        case clickCount      = "click_count"
        case bookmarkCount   = "bookmark_count"
        case favouriteCount  = "favourite_count"
    }

    var eventParameters: [String: Any] {
        let dict: [String: Any?] = [
            "user_ingredient_id": ingredientId,
            "user_author_id": authorId,
            "user_name": name,
            "user_brand_name": brandName,
            "user_description": description,
            "user_measurement_method": measurementMethod.rawValue,
            "user_calories": calories,
            "user_protein": protein,
            "user_carbs": carbs,
            "user_fat_total": fatTotal,
            "user_image_url": imageURL,
            "user_date_created": dateCreated,
            "user_date_modified": dateModified,
            "user_click_count": clickCount,
            "user_bookmark_count": bookmarkCount,
            "user_favourite_count": favouriteCount
        ]
        return dict.compactMapValues({ $0 })
    }

    static var mock: FoodModel {
        mocks[0]
    }

    static var mocks: [FoodModel] {
        [mockRolledOats, mockWholeMilk, mockChickenBreast, mockGreekYogurt, mockOliveOil, mockBanana]
    }

    // MARK: - Individual mocks (mass / volume / serving modes)

    static let mockRolledOats = FoodModel(
        ingredientId: "ing-1",
        authorId: "1",
        name: "Rolled Oats",
        brandName: "Dunnes Stores",
        description: "Whole grain oats.",
        measurementMethod: .weight,
        nutrients: [
            .calories: 389, .protein: 16.9, .carbs: 66.3, .fatTotal: 6.9,
            .fiber: 10.6, .sugar: 0.0, .sodiumMg: 2, .potassiumMg: 429,
            .calciumMg: 54, .ironMg: 4.7, .vitaminCMg: 0.0, .vitaminDMcg: 0.0,
            .magnesiumMg: 0.0, .zincMg: 0.0
        ],
        portionWeight: 40,
        weightPortionSize: 0.5,
        weightPortionName: "cup",
        imageURL: Constants.randomImage,
        dateCreated: Date(),
        dateModified: Date(),
        clickCount: 12,
        bookmarkCount: 3,
        favouriteCount: 1
    )

    static let mockWholeMilk = FoodModel(
        ingredientId: "ing-2",
        authorId: "2",
        name: "Whole Milk",
        brandName: nil,
        description: "Dairy, 3.25% fat.",
        measurementMethod: .volume,
        nutrients: [
            .calories: 61, .protein: 3.2, .carbs: 4.8, .fatTotal: 3.3,
            .sugar: 5.1, .sodiumMg: 43, .potassiumMg: 150, .calciumMg: 113,
            .ironMg: 0.0, .vitaminCMg: 0.0, .vitaminDMcg: 0.0,
            .magnesiumMg: 0.0, .zincMg: 0.0
        ],
        portionVolume: 244,
        volumePortionSize: 1,
        volumePortionName: "cup",
        imageURL: nil,
        dateCreated: Date(),
        dateModified: Date(),
        clickCount: 5,
        bookmarkCount: 1,
        favouriteCount: 0
    )

    static let mockChickenBreast = FoodModel(
        ingredientId: "ing-3",
        authorId: "1",
        name: "Chicken Breast",
        description: "Boneless, skinless chicken breast.",
        measurementMethod: .weight,
        nutrients: [
            .calories: 165, .protein: 31, .carbs: 0, .fatTotal: 3.6,
            .fiber: 0, .sugar: 0, .sodiumMg: 74, .potassiumMg: 256,
            .calciumMg: 15, .ironMg: 1, .vitaminCMg: 0, .vitaminDMcg: 0,
            .magnesiumMg: 29, .zincMg: 1
        ],
        portionWeight: 150,
        weightPortionSize: 1,
        weightPortionName: "breast",
        dateCreated: Date(),
        dateModified: Date(),
        clickCount: 20,
        bookmarkCount: 5,
        favouriteCount: 3
    )

    static let mockGreekYogurt = FoodModel(
        ingredientId: "ing-4",
        authorId: "2",
        name: "Greek Yogurt",
        description: "Plain, full-fat Greek yogurt.",
        measurementMethod: .weight,
        nutrients: [
            .calories: 97, .protein: 9, .carbs: 3.6, .fatTotal: 5,
            .fiber: 0, .sugar: 3.2, .sodiumMg: 36, .potassiumMg: 141,
            .calciumMg: 110, .ironMg: 0.1, .vitaminCMg: 0, .vitaminDMcg: 0,
            .magnesiumMg: 11, .zincMg: 0.5
        ],
        servingWeight: 245,
        portionSize: 1,
        portionName: "cup",
        dateCreated: Date(),
        dateModified: Date(),
        clickCount: 8,
        bookmarkCount: 2,
        favouriteCount: 1
    )

    static let mockOliveOil = FoodModel(
        ingredientId: "ing-5",
        authorId: "1",
        name: "Olive Oil",
        description: "Extra virgin olive oil.",
        measurementMethod: .volume,
        nutrients: [
            .calories: 884, .protein: 0, .carbs: 0, .fatTotal: 100,
            .fiber: 0, .sugar: 0, .sodiumMg: 2, .potassiumMg: 1,
            .calciumMg: 1, .ironMg: 0.6, .vitaminCMg: 0, .vitaminDMcg: 0,
            .magnesiumMg: 0, .zincMg: 0
        ],
        portionVolume: 14,
        volumePortionSize: 1,
        volumePortionName: "tbsp",
        dateCreated: Date(),
        dateModified: Date(),
        clickCount: 7,
        bookmarkCount: 1,
        favouriteCount: 0
    )

    static let mockBanana = FoodModel(
        ingredientId: "ing-6",
        authorId: "2",
        name: "Banana",
        description: "Fresh ripe banana.",
        measurementMethod: .weight,
        nutrients: [
            .calories: 89, .protein: 1.1, .carbs: 23, .fatTotal: 0.3,
            .fiber: 2.6, .sugar: 12, .sodiumMg: 1, .potassiumMg: 358,
            .calciumMg: 5, .ironMg: 0.3, .vitaminCMg: 8.7, .vitaminDMcg: 0,
            .magnesiumMg: 27, .zincMg: 0.2
        ],
        servingWeight: 118,
        portionSize: 1,
        portionName: "medium banana",
        dateCreated: Date(),
        dateModified: Date(),
        clickCount: 15,
        bookmarkCount: 4,
        favouriteCount: 2
    )
}

extension FoodModel: Sendable {}

extension FoodModel: Hashable {
    static func == (lhs: FoodModel, rhs: FoodModel) -> Bool {
        lhs.ingredientId == rhs.ingredientId
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(ingredientId)
    }
}
