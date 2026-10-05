//
//  WeightTrendRouter.swift
//  Compound
//
//  Created by Cursor on 07/02/2026.
//

import SwiftUI

@MainActor
protocol WeightTrendRouter: ScaleWeightRouter, AskCoachRouter { }

extension CoreRouter: WeightTrendRouter { }
