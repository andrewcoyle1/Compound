//
//  ExerciseTrackerInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 02/03/2026.
//

@MainActor
protocol ExerciseTrackerInteractor: GlobalInteractor {
    /// The note kept on this exercise's own settings screen, if any.
    func exerciseNote(for exerciseId: String) -> String?
}

extension CoreInteractor: ExerciseTrackerInteractor { }
