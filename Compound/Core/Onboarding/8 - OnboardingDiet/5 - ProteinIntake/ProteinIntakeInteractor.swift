//
//  ProteinIntakeInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol ProteinIntakeInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
    var currentDietPlan: DietPlan? { get }
}

extension CoreInteractor: ProteinIntakeInteractor { }
