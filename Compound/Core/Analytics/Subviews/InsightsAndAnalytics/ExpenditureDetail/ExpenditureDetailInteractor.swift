//
//  ExpenditureDetailInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 07/02/2026.
//

import SwiftUI

@MainActor
protocol ExpenditureDetailInteractor {
    var currentUser: UserModel? { get }
    var expenditureHistory: [ExpenditureEstimate] { get }
    func estimateTDEE(user: UserModel?) -> Double
}

extension CoreInteractor: ExpenditureDetailInteractor { }
