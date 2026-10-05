//
//  CalorieDistributionInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

protocol CalorieDistributionInteractor: GlobalInteractor {
    var activeMesocycle: Mesocycle? { get }
    var currentDietPlan: DietPlan? { get }
}

extension CoreInteractor: CalorieDistributionInteractor { }
