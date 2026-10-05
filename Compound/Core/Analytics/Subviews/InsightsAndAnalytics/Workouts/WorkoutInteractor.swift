//
//  WorkoutInteractor.swift
//  Compound
//
//  Created by Cursor on 07/02/2026.
//

import SwiftUI

@MainActor
protocol WorkoutInteractor: GlobalInteractor {
    var auth: UserAuthInfo? { get }
    var workoutSessions: [WorkoutSessionModel] { get }
}

extension CoreInteractor: WorkoutInteractor { }
