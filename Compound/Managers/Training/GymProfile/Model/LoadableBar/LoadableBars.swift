//
//  LoadableBars.swift
//  Compound
//
//  Created by Andrew Coyle on 21/01/2026.
//

import Foundation

struct LoadableBars: Identifiable, Codable {
    var id: String
    /// The catalogue type this item is, which exercises name. A duplicate shares its original's;
    /// a machine the user made that works as nothing in the catalogue has its own id.
    var typeId: String
    var name: String
    var description: String?
    var imageName: String?
    /// Set to the first weight when every bar was created and never changeable, so it says
    /// nothing about the bar a gym uses. Kept only so stored gyms round-trip; read
    /// `loadedBaseWeight`.
    var defaultBaseWeightId: String?
    /// The bar the user chose to load, from the plate calculator. `nil` until they choose.
    var chosenBaseWeightId: String?
    var baseWeights: [LoadableBarsBaseWeight]
    /// What one collar weighs, in kilograms whatever the bar's unit, so one figure serves a kg and
    /// a lb bar alike. Collars are always on: a loaded bar carries two.
    var collarWeight: Double
    
    var defaultBaseWeight: LoadableBarsBaseWeight? {
        baseWeights.first(where: { $0.id == self.defaultBaseWeightId })
    }

    /// The bar the gym loads: the user's choice while it is switched on, else the heaviest bar
    /// switched on. The stored default cannot be used: it was always the first weight, so the
    /// catalogue barbell meant its 7 kg technique bar and 50 kg could never be stepped to.
    var loadedBaseWeight: LoadableBarsBaseWeight? {
        let active = baseWeights.filter(\.isActive)
        return active.first { $0.id == chosenBaseWeightId }
            ?? active.max { $0.kilograms < $1.kilograms }
    }
    
    var isActive: Bool
    
    init(
        id: String,
        typeId: String? = nil,
        name: String,
        imageName: String? = nil,
        description: String?,
        baseWeights: [LoadableBarsBaseWeight],
        collarWeight: Double = 0,
        isActive: Bool
    ) {
        self.id = id
        self.typeId = typeId ?? id
        self.name = name
        self.imageName = imageName
        self.description = description
        self.defaultBaseWeightId = baseWeights.first?.id
        self.baseWeights = baseWeights
        self.collarWeight = collarWeight
        self.isActive = isActive

    }
    
    static let defaultLoadableBars: [LoadableBars] = [
        LoadableBars(
            id: "axle_bar",
            name: "Axle Bar",
            imageName: "axle_bar_icon",
            description: nil,
            baseWeights: [
                LoadableBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 7.5,
                    unit: .kilograms,
                    isActive: true
                ),
                LoadableBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 11.5,
                    unit: .kilograms,
                    isActive: true
                ),
                LoadableBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 15,
                    unit: .kilograms,
                    isActive: true
                )
            ],
            isActive: true
        ),
        LoadableBars(
            id: "barbell",
            name: "Barbell",
            imageName: "barbell_icon",
            description: nil,
            baseWeights: [
                LoadableBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 7,
                    unit: .kilograms,
                    isActive: true
                ),
                LoadableBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 15,
                    unit: .kilograms,
                    isActive: true
                ),
                LoadableBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 20,
                    unit: .kilograms,
                    isActive: true
                )
            ],
            isActive: true
        ),
        LoadableBars(
            id: "cambered_bench_bar",
            name: "Cambered Bench Bar",
            description: nil,
            baseWeights: [
                LoadableBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 20,
                    unit: .kilograms,
                    isActive: true
                )
            ],
            isActive: true
        ),
        LoadableBars(
            id: "cambered_squat_bar",
            name: "Cambered Squat Bar",
            description: nil,
            baseWeights: [
                LoadableBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 20,
                    unit: .kilograms,
                    isActive: true
                )
            ],
            isActive: true
        ),
        LoadableBars(
            id: "ez_bar",
            name: "EZ Bar",
            description: nil,
            baseWeights: [
                LoadableBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 9,
                    unit: .kilograms,
                    isActive: true
                )
            ],
            isActive: true
        ),
        LoadableBars(
            id: "safety_squat_bar",
            name: "Safety Squat Bar",
            description: nil,
            baseWeights: [
                LoadableBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 25,
                    unit: .kilograms,
                    isActive: true
                ),
                LoadableBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 27.5,
                    unit: .kilograms,
                    isActive: true
                ),
                LoadableBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 29.5,
                    unit: .kilograms,
                    isActive: true
                ),
                LoadableBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 32,
                    unit: .kilograms,
                    isActive: true
                )
            ],
            isActive: true
        ),
        LoadableBars(
            id: "strongman_log",
            name: "Strongman Log",
            description: nil,
            baseWeights: [
                LoadableBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 22.5,
                    unit: .kilograms,
                    isActive: true
                ),
                LoadableBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 32,
                    unit: .kilograms,
                    isActive: true
                ),
                LoadableBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 61,
                    unit: .kilograms,
                    isActive: true
                )
            ],
            isActive: true
        ),
        LoadableBars(
            id: "swiss_bar",
            name: "Swiss Bar",
            imageName: "swiss_bar_icon",
            description: nil,
            baseWeights: [
                LoadableBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 17.5,
                    unit: .kilograms,
                    isActive: true
                ),
                LoadableBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 20,
                    unit: .kilograms,
                    isActive: true
                )
            ],
            isActive: true
        ),
        LoadableBars(
            id: "trap_bar",
            name: "Trap Bar",
            imageName: "trap_bar_icon",
            description: nil,
            baseWeights: [
                LoadableBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 20,
                    unit: .kilograms,
                    isActive: true
                )
            ],
            isActive: true
        )
    ]
    
    static var mock: LoadableBars {
        mocks[0]
    }
    
    static let mocks: [LoadableBars] = [
        LoadableBars(
            id: "axle_bar",
            name: "Axle Bar",
            imageName: "axle_bar_icon",
            description: nil,
            baseWeights: [
                LoadableBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 7.5,
                    unit: .kilograms,
                    isActive: true
                ),
                LoadableBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 11.5,
                    unit: .kilograms,
                    isActive: true
                ),
                LoadableBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 15,
                    unit: .kilograms,
                    isActive: true
                )
            ],
            isActive: true
        ),
        LoadableBars(
            id: "barbell",
            name: "Barbell",
            imageName: "barbell_icon",
            description: nil,
            baseWeights: [
                LoadableBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 7,
                    unit: .kilograms,
                    isActive: true
                ),
                LoadableBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 15,
                    unit: .kilograms,
                    isActive: true
                ),
                LoadableBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 20,
                    unit: .kilograms,
                    isActive: true
                )
            ],
            isActive: true
        ),
        LoadableBars(
            id: "cambered_bench_bar",
            name: "Cambered Bench Bar",
            description: nil,
            baseWeights: [
                LoadableBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 20,
                    unit: .kilograms,
                    isActive: true
                )
            ],
            isActive: true
        ),
        LoadableBars(
            id: "cambered_squat_bar",
            name: "Cambered Squat Bar",
            description: nil,
            baseWeights: [
                LoadableBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 20,
                    unit: .kilograms,
                    isActive: true
                )
            ],
            isActive: true
        ),
        LoadableBars(
            id: "ez_bar",
            name: "EZ Bar",
            description: nil,
            baseWeights: [
                LoadableBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 9,
                    unit: .kilograms,
                    isActive: true
                )
            ],
            isActive: true
        ),
        LoadableBars(
            id: "safety_squat_bar",
            name: "Safety Squat Bar",
            description: nil,
            baseWeights: [
                LoadableBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 25,
                    unit: .kilograms,
                    isActive: true
                ),
                LoadableBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 27.5,
                    unit: .kilograms,
                    isActive: true
                ),
                LoadableBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 29.5,
                    unit: .kilograms,
                    isActive: true
                ),
                LoadableBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 32,
                    unit: .kilograms,
                    isActive: true
                )
            ],
            isActive: true
        ),
        LoadableBars(
            id: "strongman_log",
            name: "Strongman Log",
            description: nil,
            baseWeights: [
                LoadableBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 22.5,
                    unit: .kilograms,
                    isActive: true
                ),
                LoadableBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 32,
                    unit: .kilograms,
                    isActive: true
                ),
                LoadableBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 61,
                    unit: .kilograms,
                    isActive: true
                )
            ],
            isActive: true
        ),
        LoadableBars(
            id: "swiss_bar",
            name: "Swiss Bar",
            imageName: "swiss_bar_icon",
            description: nil,
            baseWeights: [
                LoadableBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 17.5,
                    unit: .kilograms,
                    isActive: true
                ),
                LoadableBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 20,
                    unit: .kilograms,
                    isActive: true
                )
            ],
            isActive: true
        ),
        LoadableBars(
            id: "trap_bar",
            name: "Trap Bar",
            imageName: "trap_bar_icon",
            description: nil,
            baseWeights: [
                LoadableBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 20,
                    unit: .kilograms,
                    isActive: true
                )
            ],
            isActive: true
        )
    ]
}

struct LoadableBarsBaseWeight: Identifiable, Codable {
    var id: String
    
    var baseWeight: Double
    
    var unit: ExerciseWeightUnit
    
    var isActive: Bool

    var kilograms: Double { UnitConversion.convertWeightToKg(baseWeight, from: unit) }
}

// MARK: - Decoding

extension LoadableBars {
    /// The keys match the property names, which is the wire format these items have always had.
    /// The id and name are required; a missing `isActive` reads as off, so a damaged item never
    /// offers equipment the user did not confirm. See `GymEquipmentDecoding.swift`.
    enum CodingKeys: String, CodingKey {
        case id, typeId, name, imageName, description, defaultBaseWeightId, chosenBaseWeightId, baseWeights, collarWeight, isActive
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        self.id = id
        // Items saved before custom and duplicate machines are their own type.
        typeId = try container.decodeIfPresent(String.self, forKey: .typeId) ?? id
        name = try container.decode(String.self, forKey: .name)
        imageName = try container.decodeIfPresent(String.self, forKey: .imageName)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        defaultBaseWeightId = try container.decodeIfPresent(String.self, forKey: .defaultBaseWeightId)
        chosenBaseWeightId = try container.decodeIfPresent(String.self, forKey: .chosenBaseWeightId)
        baseWeights = container.decodeLossyArray(LoadableBarsBaseWeight.self, forKey: .baseWeights) ?? []
        collarWeight = try container.decodeIfPresent(Double.self, forKey: .collarWeight) ?? 0
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? false
    }
}

extension LoadableBarsBaseWeight {
    /// The keys match the property names, which is the wire format these items have always had.
    /// The weights stay required: there is no sensible default for one, and a zero would reach
    /// arithmetic that divides by it. An entry without them is skipped by its parent's lossy list.
    enum CodingKeys: String, CodingKey {
        case id, baseWeight, unit, isActive
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        baseWeight = try container.decode(Double.self, forKey: .baseWeight)
        unit = try container.decodeIfPresent(ExerciseWeightUnit.self, forKey: .unit) ?? .kilograms
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? false
    }
}
