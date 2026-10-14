//
//  PlateCalculatorRouter.swift
//  Compound
//

@MainActor
protocol PlateCalculatorRouter: GlobalRouter { }

extension CoreRouter: PlateCalculatorRouter { }
