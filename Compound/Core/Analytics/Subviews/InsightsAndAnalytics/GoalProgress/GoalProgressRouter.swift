//
//  GoalProgressRouter.swift
//  Compound
//

import SwiftUI

@MainActor
protocol GoalProgressRouter: ScaleWeightRouter { }

extension CoreRouter: GoalProgressRouter { }
