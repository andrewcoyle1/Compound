//
//  LogMeasurementRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 21/09/2026.
//

@MainActor
protocol LogMeasurementRouter: GlobalRouter {
    func dismissScreen()
}

extension CoreRouter: LogMeasurementRouter { }
