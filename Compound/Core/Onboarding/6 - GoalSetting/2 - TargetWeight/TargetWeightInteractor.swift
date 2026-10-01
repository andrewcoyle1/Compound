//
//  TargetWeightInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol TargetWeightInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
    var currentWeightKilograms: Double? { get }
}

extension CoreInteractor: TargetWeightInteractor { }
