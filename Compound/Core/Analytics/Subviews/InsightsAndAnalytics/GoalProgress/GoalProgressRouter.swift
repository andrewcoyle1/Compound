//
//  GoalProgressRouter.swift
//  Compound
//

import SwiftUI

@MainActor
protocol GoalProgressRouter: ScaleWeightRouter, WeightGoalFlowRouter { }

extension CoreRouter: GoalProgressRouter { }
