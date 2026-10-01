//
//  FoodsRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol FoodsRouter {
    func showFoodDetailView(delegate: FoodDetailDelegate)
    func showSimpleAlert(title: String, subtitle: String?)
}

extension CoreRouter: FoodsRouter { }
