//
//  ExerciseDetailInteractor.swift
//  Compound
//
//  Created by Cursor on 07/02/2026.
//

import SwiftUI

@MainActor
protocol ExerciseDetailInteractor: GlobalInteractor {
    var auth: UserAuthInfo? { get }
    var workoutSessions: [WorkoutSessionModel] { get }
    func getPreference(templateId: String) -> ExerciseUnitPreference
}

extension CoreInteractor: ExerciseDetailInteractor { }
