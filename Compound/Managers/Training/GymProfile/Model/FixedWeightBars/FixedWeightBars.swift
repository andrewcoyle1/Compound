//
//  FixedWeightBars.swift
//  Compound
//
//  Created by Andrew Coyle on 21/01/2026.
//

import Foundation

struct FixedWeightBars: Identifiable, Codable {
    var id: String
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
        name: String,
        imageName: String? = nil,
        description: String?,
        baseWeights: [FixedWeightBarsBaseWeight],
        isActive: Bool
    ) {
        self.id = id
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
