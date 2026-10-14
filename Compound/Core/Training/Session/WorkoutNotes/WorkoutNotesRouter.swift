//
//  WorkoutNotesRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 05/12/2025.
//

@MainActor
protocol WorkoutNotesRouter: GlobalRouter { }

extension CoreRouter: WorkoutNotesRouter { }
