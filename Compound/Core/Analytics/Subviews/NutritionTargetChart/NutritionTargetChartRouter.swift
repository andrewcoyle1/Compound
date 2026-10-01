//
//  NutritionTargetChartRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 22/09/2026.
//

/// The one destination the weekly target grid needs: the diet questionnaire that ends in a saved
/// plan. It is the same entry Settings uses, so the flow dismisses back here when it is done
/// rather than continuing into onboarding.
@MainActor
protocol NutritionTargetChartRouter: GlobalRouter {
    func showPreferredDietView(isFromSettings: Bool)
}

extension CoreRouter: NutritionTargetChartRouter { }
