//
//  WeightRateInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol WeightRateInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
    var currentWeightKilograms: Double? { get }
    func estimateTDEE(user: UserModel?) -> Double
}

extension CoreInteractor: WeightRateInteractor { }
