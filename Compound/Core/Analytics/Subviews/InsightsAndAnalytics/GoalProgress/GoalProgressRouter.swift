//
//  GoalProgressRouter.swift
//  Compound
//

import SwiftUI

@MainActor
protocol GoalProgressRouter: ScaleWeightRouter {
    func showWeightGoalFlow()
}

extension CoreRouter: GoalProgressRouter { }
