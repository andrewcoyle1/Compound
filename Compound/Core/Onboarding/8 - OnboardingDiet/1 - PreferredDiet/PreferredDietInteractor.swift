//
//  PreferredDietInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol PreferredDietInteractor: GlobalInteractor {
    var currentDietPlan: DietPlan? { get }
}

extension CoreInteractor: PreferredDietInteractor { }
