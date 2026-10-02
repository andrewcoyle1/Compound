//
//  WeightRange.swift
//  Compound
//
//  Created by Andrew Coyle on 21/01/2026.
//

protocol WeightRange: Identifiable, Codable {
    var id: String { get }
    
    var minWeight: Double { get set }
    var maxWeight: Double { get set }
    var increment: Double { get set }
    
    var unit: ExerciseWeightUnit { get }

}
