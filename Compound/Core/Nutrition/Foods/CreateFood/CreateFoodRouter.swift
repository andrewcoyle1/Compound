//
//  CreateFoodRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol CreateFoodRouter: GlobalRouter {
    func showPortionDefinitionView(delegate: PortionDefinitionDelegate)
    func showFoodPackagingView(delegate: FoodPackagingDelegate)
#if !targetEnvironment(macCatalyst)
    func showBarcodeScannerView(delegate: BarcodeScannerDelegate)
    #endif
}

extension CoreRouter: CreateFoodRouter { }
