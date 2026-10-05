//
//  WorkoutNotesInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 05/12/2025.
//

@MainActor
protocol WorkoutNotesInteractor: GlobalInteractor { }

extension CoreInteractor: WorkoutNotesInteractor { }
