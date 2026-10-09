//
//  FixedWeightBars.swift
//  Compound
//
//  Created by Andrew Coyle on 21/01/2026.
//

import Foundation

struct FixedWeightBars: Identifiable, Codable {
    var id: String
    /// The catalogue type this item is, which exercises name. A duplicate shares its original's;
    /// a machine the user made that works as nothing in the catalogue has its own id.
    var typeId: String
    var name: String
    var imageName: String?
    var description: String?
    var defaultBaseWeightId: String?
    var baseWeights: [FixedWeightBarsBaseWeight]
    
    var defaultBaseWeight: FixedWeightBarsBaseWeight? {
        baseWeights.first(where: { $0.id == self.defaultBaseWeightId })
    }

    var isActive: Bool
    
    init(
        id: String,
        typeId: String? = nil,
        name: String,
        imageName: String? = nil,
        description: String?,
        baseWeights: [FixedWeightBarsBaseWeight],
        isActive: Bool
    ) {
        self.id = id
        self.typeId = typeId ?? id
        self.name = name
        self.imageName = imageName
        self.description = description
        self.defaultBaseWeightId = baseWeights.first?.id
        self.baseWeights = baseWeights
        self.isActive = isActive

    }
    
    static let defaultFixedWeightBars: [FixedWeightBars] = [
        FixedWeightBars(
            id: "fixed_weight_ez_bar",
            name: "Fixed Weight Ez Bar",
            description: nil,
            baseWeights: [
                FixedWeightBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 10,
                    unit: .kilograms,
                    isActive: true
                ),
                FixedWeightBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 15,
                    unit: .kilograms,
                    isActive: true
                ),
                FixedWeightBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 20,
                    unit: .kilograms,
                    isActive: true
                ),
                FixedWeightBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 25,
                    unit: .kilograms,
                    isActive: true
                ),
                FixedWeightBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 30,
                    unit: .kilograms,
                    isActive: true
                ),
                FixedWeightBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 35,
                    unit: .kilograms,
                    isActive: true
                ),
                FixedWeightBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 40,
                    unit: .kilograms,
                    isActive: true
                ),
                FixedWeightBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 45,
                    unit: .kilograms,
                    isActive: true
                ),
                FixedWeightBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 50,
                    unit: .kilograms,
                    isActive: true
                )
            ],
            isActive: true
        ),
        FixedWeightBars(
            id: "fixed_weight_straight_bar",
            name: "Fixed Weight Straight Bar",
            description: nil,
            baseWeights: [
                FixedWeightBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 10,
                    unit: .kilograms,
                    isActive: true
                ),
                FixedWeightBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 15,
                    unit: .kilograms,
                    isActive: true
                ),
                FixedWeightBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 20,
                    unit: .kilograms,
                    isActive: true
                ),
                FixedWeightBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 25,
                    unit: .kilograms,
                    isActive: true
                ),
                FixedWeightBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 30,
                    unit: .kilograms,
                    isActive: true
                ),
                FixedWeightBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 35,
                    unit: .kilograms,
                    isActive: true
                ),
                FixedWeightBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 40,
                    unit: .kilograms,
                    isActive: true
                ),
                FixedWeightBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 45,
                    unit: .kilograms,
                    isActive: true
                ),
                FixedWeightBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 50,
                    unit: .kilograms,
                    isActive: true
                )
            ],
            isActive: true
        )
    ]
    
    static var mock: FixedWeightBars {
        mocks[0]
    }
    
    static let mocks: [FixedWeightBars] = [
        FixedWeightBars(
            id: "fixed_weight_ez_bar",
            name: "Fixed Weight Ez Bar",
            description: nil,
            baseWeights: [
                FixedWeightBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 10,
                    unit: .kilograms,
                    isActive: true
                ),
                FixedWeightBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 15,
                    unit: .kilograms,
                    isActive: true
                ),
                FixedWeightBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 20,
                    unit: .kilograms,
                    isActive: true
                ),
                FixedWeightBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 25,
                    unit: .kilograms,
                    isActive: true
                ),
                FixedWeightBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 30,
                    unit: .kilograms,
                    isActive: true
                ),
                FixedWeightBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 35,
                    unit: .kilograms,
                    isActive: true
                ),
                FixedWeightBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 40,
                    unit: .kilograms,
                    isActive: true
                ),
                FixedWeightBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 45,
                    unit: .kilograms,
                    isActive: true
                ),
                FixedWeightBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 50,
                    unit: .kilograms,
                    isActive: true
                )
            ],
            isActive: true
        ),
        FixedWeightBars(
            id: "fixed_weight_straight_bar",
            name: "Fixed Weight Straight Bar",
            description: nil,
            baseWeights: [
                FixedWeightBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 10,
                    unit: .kilograms,
                    isActive: true
                ),
                FixedWeightBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 15,
                    unit: .kilograms,
                    isActive: true
                ),
                FixedWeightBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 20,
                    unit: .kilograms,
                    isActive: true
                ),
                FixedWeightBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 25,
                    unit: .kilograms,
                    isActive: true
                ),
                FixedWeightBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 30,
                    unit: .kilograms,
                    isActive: true
                ),
                FixedWeightBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 35,
                    unit: .kilograms,
                    isActive: true
                ),
                FixedWeightBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 40,
                    unit: .kilograms,
                    isActive: true
                ),
                FixedWeightBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 45,
                    unit: .kilograms,
                    isActive: true
                ),
                FixedWeightBarsBaseWeight(
                    id: UUID().uuidString,
                    baseWeight: 50,
                    unit: .kilograms,
                    isActive: true
                )
            ],
            isActive: true
        )
    ]
}

struct FixedWeightBarsBaseWeight: Identifiable, Codable {
    var id: String
    
    var baseWeight: Double
    
    var unit: ExerciseWeightUnit
    
    var isActive: Bool
}

// MARK: - Decoding

extension FixedWeightBars {
    /// The keys match the property names, which is the wire format these items have always had.
    /// The id and name are required; a missing `isActive` reads as off, so a damaged item never
    /// offers equipment the user did not confirm. See `GymEquipmentDecoding.swift`.
    enum CodingKeys: String, CodingKey {
        case id, typeId, name, imageName, description, defaultBaseWeightId, baseWeights, isActive
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
        baseWeights = container.decodeLossyArray(FixedWeightBarsBaseWeight.self, forKey: .baseWeights) ?? []
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? false
    }
}

extension FixedWeightBarsBaseWeight {
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
