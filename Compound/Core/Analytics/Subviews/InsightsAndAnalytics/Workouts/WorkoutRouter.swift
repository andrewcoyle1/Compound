//
//  WorkoutRouter.swift
//  Compound
//
//  Created by Cursor on 07/02/2026.
//

import SwiftUI

@MainActor
protocol WorkoutRouter: GlobalRouter {
    func showWorkoutsView(delegate: WorkoutsDelegate)
}

extension CoreRouter: WorkoutRouter { }
