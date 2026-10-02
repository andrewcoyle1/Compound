//
//  CustomisingDietProgramInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol CustomisingDietProgramInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
}

extension CoreInteractor: CustomisingDietProgramInteractor { }
