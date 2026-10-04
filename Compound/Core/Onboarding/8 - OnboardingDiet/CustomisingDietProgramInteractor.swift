//
//  CustomisingDietProgramInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol CustomisingDietProgramInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
    var activeMesocycle: Mesocycle? { get }
}

extension CoreInteractor: CustomisingDietProgramInteractor { }
