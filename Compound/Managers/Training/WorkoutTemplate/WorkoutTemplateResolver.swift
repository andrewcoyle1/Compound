//
//  WorkoutTemplateResolver.swift
//  Compound
//
//  Created by Andrew Coyle on 25/10/2025.
//

import Foundation

/// Protocol for resolving workout template names by ID.
/// This abstraction enables dependency inversion and package modularity.
protocol WorkoutTemplateResolver {
    func getLocalWorkoutTemplate(id: String) throws -> WorkoutTemplateModel
}
