//
//  ProteinIntakeInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol ProteinIntakeInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
}

extension CoreInteractor: ProteinIntakeInteractor { }
