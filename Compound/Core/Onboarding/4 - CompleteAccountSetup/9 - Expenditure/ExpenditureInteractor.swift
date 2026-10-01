//
//  ExpenditureInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol ExpenditureInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
    func saveUserCompleteAccountSetup(input: [String: any DMCodableSendable]) async throws
    func estimateTDEE(user: UserModel?) -> Double
}

extension CoreInteractor: ExpenditureInteractor { }
