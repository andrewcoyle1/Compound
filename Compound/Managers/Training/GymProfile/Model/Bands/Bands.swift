//
//  Bands.swift
//  Compound
//
//  Created by Andrew Coyle on 21/01/2026.
//

import SwiftUI

struct Bands: Identifiable, Codable {
    var id: String
    var name: String
    var imageName: String?
    var description: String?
    var range: [BandsAvailable]
    
    var isActive: Bool
    
    init(
        id: String,
        name: String,
        imageName: String? = nil,
        description: String? = nil,
        range: [BandsAvailable],
        isActive: Bool
    ) {
        self.id = id
        self.name = name
        self.imageName = imageName
        self.description = description
        self.range = range
        self.isActive = isActive
    }
}

extension Bands {
    static var defaultBands: [Bands] { BandsDefaultData.defaultBands }
    static var mock: Bands { BandsDefaultData.mocks[0] }
    static var mocks: [Bands] { BandsDefaultData.mocks }
}

private enum BandsDefaultData {
    static let defaultBands: [Bands] = [
        Bands(
            id: "long_elastic_bands",
            name: "Long Elastic Bands",
            description: nil,
            range: longElasticBandsRangeKgAndLbs,
            isActive: true
        ),
        Bands(
            id: "short_elastic_bands",
            name: "Short Elastic Bands",
            description: nil,
            range: shortElasticBandsRange,
            isActive: true
        )
    ]
    static let mocks: [Bands] = defaultBands

    private static let longElasticBandsRangeKgAndLbs: [BandsAvailable] = [
        BandsAvailable(id: UUID().uuidString, name: "Extra Light Resistance", bandColour: Color.orange.asHex(), availableResistance: 4, unit: .kilograms, isActive: true),
        BandsAvailable(id: UUID().uuidString, name: "Light Resistance", bandColour: Color.red.asHex(), availableResistance: 8, unit: .kilograms, isActive: true),
        BandsAvailable(id: UUID().uuidString, name: "Medium Resistance", bandColour: Color.blue.asHex(), availableResistance: 14, unit: .kilograms, isActive: true),
        BandsAvailable(id: UUID().uuidString, name: "Medium-Heavy Resistance", bandColour: Color.green.asHex(), availableResistance: 18, unit: .kilograms, isActive: true),
        BandsAvailable(id: UUID().uuidString, name: "Heavy Resistance", bandColour: Color.black.asHex(), availableResistance: 30, unit: .kilograms, isActive: true),
        BandsAvailable(id: UUID().uuidString, name: "Extra Heavy Resistance", bandColour: Color.purple.asHex(), availableResistance: 43, unit: .kilograms, isActive: true),
        BandsAvailable(id: UUID().uuidString, name: "Super Heavy Resistance", bandColour: Color.red.asHex(), availableResistance: 52, unit: .kilograms, isActive: true),
        BandsAvailable(id: UUID().uuidString, name: "Heaviest Resistance", bandColour: Color.gray.asHex(), availableResistance: 102, unit: .kilograms, isActive: true),
        BandsAvailable(id: UUID().uuidString, name: "Extra Light Resistance", bandColour: Color.orange.asHex(), availableResistance: 9, unit: .pounds, isActive: false),
        BandsAvailable(id: UUID().uuidString, name: "Light Resistance", bandColour: Color.red.asHex(), availableResistance: 18, unit: .pounds, isActive: false),
        BandsAvailable(id: UUID().uuidString, name: "Medium Resistance", bandColour: Color.blue.asHex(), availableResistance: 30, unit: .pounds, isActive: false),
        BandsAvailable(id: UUID().uuidString, name: "Medium-Heavy Resistance", bandColour: Color.green.asHex(), availableResistance: 40, unit: .pounds, isActive: false),
        BandsAvailable(id: UUID().uuidString, name: "Heavy Resistance", bandColour: Color.black.asHex(), availableResistance: 65, unit: .pounds, isActive: false),
        BandsAvailable(id: UUID().uuidString, name: "Extra Heavy Resistance", bandColour: Color.purple.asHex(), availableResistance: 95, unit: .pounds, isActive: false),
        BandsAvailable(id: UUID().uuidString, name: "Super Heavy Resistance", bandColour: Color.red.asHex(), availableResistance: 115, unit: .pounds, isActive: false),
        BandsAvailable(id: UUID().uuidString, name: "Heaviest Resistance", bandColour: Color.gray.asHex(), availableResistance: 225, unit: .pounds, isActive: false)
    ]
    private static let shortElasticBandsRange: [BandsAvailable] = [
        BandsAvailable(id: UUID().uuidString, name: "Extra Light Resistance", bandColour: Color.orange.asHex(), availableResistance: 4, unit: .kilograms, isActive: true),
        BandsAvailable(id: UUID().uuidString, name: "Light Resistance", bandColour: Color.red.asHex(), availableResistance: 8, unit: .kilograms, isActive: true),
        BandsAvailable(id: UUID().uuidString, name: "Medium Resistance", bandColour: Color.blue.asHex(), availableResistance: 14, unit: .kilograms, isActive: true),
        BandsAvailable(id: UUID().uuidString, name: "Medium-Heavy Resistance", bandColour: Color.green.asHex(), availableResistance: 18, unit: .kilograms, isActive: true),
        BandsAvailable(id: UUID().uuidString, name: "Heavy Resistance", bandColour: Color.black.asHex(), availableResistance: 30, unit: .kilograms, isActive: true),
        BandsAvailable(id: UUID().uuidString, name: "Extra Heavy Resistance", bandColour: Color.purple.asHex(), availableResistance: 43, unit: .kilograms, isActive: true),
        BandsAvailable(id: UUID().uuidString, name: "Extra Light Resistance", bandColour: Color.orange.asHex(), availableResistance: 9, unit: .pounds, isActive: false),
        BandsAvailable(id: UUID().uuidString, name: "Light Resistance", bandColour: Color.red.asHex(), availableResistance: 18, unit: .pounds, isActive: false),
        BandsAvailable(id: UUID().uuidString, name: "Medium Resistance", bandColour: Color.blue.asHex(), availableResistance: 30, unit: .pounds, isActive: false),
        BandsAvailable(id: UUID().uuidString, name: "Medium-Heavy Resistance", bandColour: Color.green.asHex(), availableResistance: 40, unit: .pounds, isActive: false),
        BandsAvailable(id: UUID().uuidString, name: "Heavy Resistance", bandColour: Color.black.asHex(), availableResistance: 65, unit: .pounds, isActive: false),
        BandsAvailable(id: UUID().uuidString, name: "Extra Heavy Resistance", bandColour: Color.purple.asHex(), availableResistance: 95, unit: .pounds, isActive: false)
    ]
}

struct BandsAvailable: Identifiable, Codable {
    var id: String
    
    var name: String
    var bandColour: String
    var availableResistance: Double
    var unit: ExerciseWeightUnit
    
    var isActive: Bool
}
