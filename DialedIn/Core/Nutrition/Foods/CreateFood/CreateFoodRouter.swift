//
//  CreateFoodRouter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol CreateFoodRouter: GlobalRouter {
    func showPortionDefinitionView(delegate: PortionDefinitionDelegate)
    func showFoodPackagingView(delegate: FoodPackagingDelegate)
    func showBarcodeScannerView(delegate: BarcodeScannerDelegate)
}

extension CoreRouter: CreateFoodRouter { }
