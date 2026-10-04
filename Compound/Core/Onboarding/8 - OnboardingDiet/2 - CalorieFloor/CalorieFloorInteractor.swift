//
//  CalorieFloorInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol CalorieFloorInteractor: GlobalInteractor {
    var currentDietPlan: DietPlan? { get }
}

extension CoreInteractor: CalorieFloorInteractor { }
